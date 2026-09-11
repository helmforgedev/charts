// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';

function totp(secret,time){
 let bits='';for(const character of secret.replace(/=+$/,'')){const index='ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'.indexOf(character.toUpperCase());assert.ok(index>=0);bits+=index.toString(2).padStart(5,'0');}
 const bytes=[];for(let index=0;index+8<=bits.length;index+=8)bytes.push(parseInt(bits.slice(index,index+8),2));
 const counter=Buffer.alloc(8);counter.writeBigUInt64BE(BigInt(Math.floor(time/30000)));
 const digest=createHmac('sha1',Buffer.from(bytes)).update(counter).digest();const offset=digest.at(-1)&15;
 return String((digest.readUInt32BE(offset)&0x7fffffff)%1000000).padStart(6,'0');
}

export async function enableAndVerifyOtp({request,password,email,apiKey}){
 const setupPath='/api/v1/users/me/two_factor/setup',confirmPath='/api/v1/users/me/two_factor/confirm';
 assert.equal((await request(setupPath,{method:'POST',json:{password:'incorrect-owned-fixture'}})).status,401);
 const setup=await request(setupPath,{method:'POST',json:{password}});assert.equal(setup.status,200,'Native OTP setup failed');
 const data=await setup.json();assert.ok(data.secret);assert.match(data.provisioning_uri,/^otpauth:\/\/totp\//);
 assert.equal((await request(confirmPath,{method:'POST',json:{password,otp_code:'invalid'}})).status,422);
 const code=totp(data.secret,Date.parse(setup.headers.get('date')));
 const confirm=await request(confirmPath,{method:'POST',json:{password,otp_code:code}});assert.equal(confirm.status,200,'Native OTP confirmation failed');
 const backupCodes=(await confirm.json()).backup_codes;assert.equal(backupCodes.length,10);
 async function challenge(){const response=await request('/api/v1/auth/login',{method:'POST',anonymous:true,json:{email,password}});assert.equal(response.status,202,'Password alone must not return an API key after OTP enrollment');const body=await response.json();assert.equal(body.two_factor_required,true);assert.equal(body.api_key,undefined);return body.challenge_token;}
 const submit=(token,otp_code)=>request('/api/v1/auth/otp_challenge',{method:'POST',anonymous:true,json:{challenge_token:token,otp_code}});
 const token=await challenge();assert.equal((await submit(token,'invalid')).status,401);
 const authenticated=await submit(token,code);assert.equal(authenticated.status,200);assert.equal((await authenticated.json()).api_key,apiKey);
 assert.equal((await submit(token,code)).status,401,'Consumed challenge must not be reusable');
 const reused=await challenge();assert.equal((await submit(reused,code)).status,401,'Consumed TOTP must not be reusable');
 const backup=backupCodes.shift();const recovered=await submit(reused,backup);assert.equal(recovered.status,200);assert.equal((await recovered.json()).api_key,apiKey);
 assert.equal((await submit(await challenge(),backup)).status,401,'Consumed backup code must not be reusable');
 console.log('PASS native OTP enrollment, password-only denial, TOTP/challenge replay rejection and single-use recovery codes');
 return {backupCodes};
}

export async function finishOtpLogin(request,result,state){
 assert.ok(state?.backupCodes.length,'OTP recovery fixture state is required');
 assert.equal(result.two_factor_required,true);assert.equal(result.api_key,undefined);
 const response=await request('/api/v1/auth/otp_challenge',{method:'POST',anonymous:true,json:{challenge_token:result.challenge_token,otp_code:state.backupCodes.shift()}});
 assert.equal(response.status,200,'Retained OTP keys and recovery code must complete login');return response.json();
}
