// SPDX-License-Identifier: Apache-2.0
import {createRequire} from 'node:module';
import {environment,redisTls} from './start.mjs';
environment();
const timeout=setTimeout(()=>process.exit(1),4500);
const require=createRequire('/app/package.json'),{PrismaClient}=require('@prisma/client'),Redis=require('ioredis');
const url=new URL(process.env.HF_PRISMA_URL);url.searchParams.set('connection_limit','1');url.searchParams.set('connect_timeout','3');
const prisma=new PrismaClient({datasourceUrl:url.toString()}),redis=new Redis({host:process.env.REDIS_SERVER_HOST,port:Number(process.env.REDIS_SERVER_PORT),username:process.env.REDIS_SERVER_USERNAME||undefined,password:process.env.REDIS_SERVER_PASSWORD,db:Number(process.env.REDIS_SERVER_DATABASE),tls:redisTls(),lazyConnect:true,connectTimeout:3000,maxRetriesPerRequest:0,retryStrategy:()=>null});redis.on('error',()=>{});
try{
 const [response,,pong]=await Promise.all([fetch('http://127.0.0.1:'+process.env.AFFINE_SERVER_PORT+'/info',{signal:AbortSignal.timeout(3000)}),prisma.$queryRawUnsafe('SELECT 1'),redis.connect().then(()=>redis.ping())]);
 if(!response.ok||pong!=='PONG')process.exitCode=1;
}catch{process.exitCode=1;}finally{redis.disconnect();await prisma.$disconnect();clearTimeout(timeout);}
