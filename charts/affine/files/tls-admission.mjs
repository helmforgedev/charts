// SPDX-License-Identifier: Apache-2.0
// Invoked only by the chart-owned external-dependency verification scenario.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createRequire} from 'node:module';
import {lookup} from 'node:dns/promises';
import {environment,redisTls} from './start.mjs';
environment();
const require=createRequire('/app/package.json'),{PrismaClient}=require('@prisma/client'),Redis=require('ioredis');
const binary=fs.readdirSync('/app/dist').find(name=>/^server-native\..*\.node$/.test(name));assert.ok(binary);
const {BackendRuntime,StorageRuntime}=require('/app/dist/'+binary);
const originalNative=process.env.DATABASE_URL,originalPrisma=process.env.HF_PRISMA_URL;
const denied=async(run,label)=>{let failure;try{await run();}catch(error){failure=error;}assert.ok(failure,label+' unexpectedly succeeded');assert.match(String(failure.message),/certificate|issuer|UnknownIssuer|NotValidForName|valid.*name|TLS|SSL/i,label+' must fail for TLS verification');console.log('PASS '+label);};
try{
 if(process.env.HF_POSTGRES_TLS==='true'){
  const ip=(await lookup(process.env.PGHOST,{family:4})).address;
  for(const kind of ['untrusted','wrong-host']){
   const prismaUrl=new URL(originalPrisma),nativeUrl=new URL(originalNative);
   if(kind==='untrusted'){prismaUrl.searchParams.delete('sslcert');nativeUrl.searchParams.delete('sslrootcert');}else{prismaUrl.hostname=ip;nativeUrl.hostname=ip;}
   const prisma=new PrismaClient({datasourceUrl:prismaUrl.toString()});try{await denied(()=>prisma.$queryRawUnsafe('SELECT 1'),'Prisma '+kind+' certificate');}finally{await prisma.$disconnect();}
   process.env.DATABASE_URL=nativeUrl.toString();
   for(const C of [BackendRuntime,StorageRuntime]){const r=C===BackendRuntime?new C(fs.readFileSync('/home/node/.affine/config/private.key','utf8'),[]):new C([]);try{await denied(()=>r.start(),C.name+' '+kind+' certificate');}finally{await r.stop();}}
  }
  process.env.DATABASE_URL=originalNative;
  const prisma=new PrismaClient({datasourceUrl:originalPrisma});try{const rows=await prisma.$queryRawUnsafe('SELECT ssl FROM pg_stat_ssl WHERE pid=pg_backend_pid()');assert.equal(rows[0]?.ssl,true);console.log('PASS positive Prisma session uses TLS');}finally{await prisma.$disconnect();}
 }
 if(process.env.HF_REDIS_TLS==='true'){
  for(const kind of ['untrusted','wrong-host']){
   const tls={...redisTls()};if(kind==='untrusted')delete tls.ca;else tls.servername='wrong-name.invalid';
   const redis=new Redis({host:process.env.REDIS_SERVER_HOST,port:Number(process.env.REDIS_SERVER_PORT),username:process.env.REDIS_SERVER_USERNAME||undefined,password:process.env.REDIS_SERVER_PASSWORD,tls,lazyConnect:true,connectTimeout:5000,maxRetriesPerRequest:0,retryStrategy:()=>null});let tlsError;redis.on('error',error=>{tlsError=error;});
   try{await denied(()=>redis.connect().catch(error=>{throw tlsError??error;}),'Redis '+kind+' certificate');}finally{redis.disconnect();}
  }
 }
}catch(error){let message=String(error.stack??error);for(const secret of [process.env.PGPASSWORD,process.env.REDIS_SERVER_PASSWORD,originalNative,originalPrisma])if(secret)message=message.replaceAll(secret,'[REDACTED]');console.error(message);process.exitCode=1;}
