// SPDX-License-Identifier: Apache-2.0
import fs from 'node:fs';
import {createPrivateKey,generateKeyPairSync} from 'node:crypto';
import {createRequire} from 'node:module';
import {execFileSync} from 'node:child_process';
import {networkInterfaces} from 'node:os';
import {once} from 'node:events';
import {environment,nativeServer,redisTls} from './start.mjs';
process.umask(0o077);environment();
const require=createRequire('/app/package.json'),{PrismaClient}=require('@prisma/client'),Redis=require('ioredis');
const prisma=new PrismaClient({datasourceUrl:process.env.HF_PRISMA_URL}),configDir='/home/node/.affine/config',configFile=configDir+'/config.json',marker=configDir+'/.helmforge-managed-config',port=Number(process.env.AFFINE_SERVER_PORT),origin=process.env.AFFINE_SERVER_EXTERNAL_URL;
let child;
const delay=ms=>new Promise(r=>setTimeout(r,ms));
async function sql(query){return prisma.$queryRawUnsafe(query);}
async function initialized(){const response=await fetch('http://127.0.0.1:'+port+'/graphql',{method:'POST',headers:{'Content-Type':'application/json',Origin:origin,Host:new URL(origin).host},body:JSON.stringify({query:'query { serverConfig { initialized } }'}),signal:AbortSignal.timeout(4000)});if(!response.ok)throw Error('Private initialized query failed');const result=await response.json();if(result.errors||typeof result.data?.serverConfig?.initialized!=='boolean')throw Error('Invalid native initialized result');return result.data.serverConfig.initialized;}
async function stop(){if(child&&child.exitCode===null&&child.signalCode===null){const done=once(child,'exit');child.kill('SIGTERM');const timer=setTimeout(()=>child.kill('SIGKILL'),15000);await done;clearTimeout(timer);}}
try{
 fs.mkdirSync(configDir,{recursive:true});fs.mkdirSync('/home/node/.affine/storage',{recursive:true});
 if(fs.existsSync('/app/config.json'))throw Error('Unexpected image-level configuration; review precedence before bootstrap');
 if(fs.existsSync(configFile)&&!fs.existsSync(marker))throw Error('Existing configuration is not chart-managed; migrate explicitly without overwriting it');
 const config={server:{externalUrl:origin,port,listenAddr:'127.0.0.1'},db:{prisma:{datasourceUrl:process.env.HF_PRISMA_URL}},auth:{allowSignup:false,allowSignupForOauth:false},flags:{allowGuestDemoWorkspace:false},metrics:{enabled:false},redis:{ioredis:{...(redisTls()?{tls:redisTls()}:{})}}};
 fs.writeFileSync(configFile,JSON.stringify(config));fs.writeFileSync(marker,'Managed runtime configuration; administrator DB settings remain authoritative.\n');
 const deadline=Date.now()+120000;let connected=false;
 while(Date.now()<deadline){try{await sql('SELECT 1');connected=true;break;}catch{await delay(1500);}}
 if(!connected)throw Error('PostgreSQL did not become reachable');
 const vector=await sql("SELECT extversion FROM pg_extension WHERE extname='vector'");if(vector.length!==1)throw Error('DBA must install vector before native migrations');
 const tables=await sql("SELECT to_regclass('users')::text AS users, to_regclass('app_configs')::text AS configs, to_regclass('_prisma_migrations')::text AS migrations");
 const existingUsers=tables[0].users?await prisma.user.count():0;
 if(existingUsers&&!fs.existsSync(configDir+'/private.key'))throw Error('Existing database requires its original private.key; restore the matching configuration volume');
 if(!existingUsers&&tables[0].configs&&await prisma.appConfig.count())throw Error('Empty-user database contains existing application overrides; explicit review required');
 if(existingUsers&&!await prisma.userFeature.count({where:{name:'administrator',activated:true}}))throw Error('Existing database has no active administrator; repair through native administration before startup');
 if(tables[0].configs){const managed=await prisma.appConfig.findMany({where:{id:{in:['db.prisma','db.datasourceUrl','redis.host','redis.port','redis.username','redis.password','redis.db','redis.ioredis','server.listenAddr','server.port','server.externalUrl']}},select:{id:true}});if(managed.length)throw Error('Database overrides conflict with chart-managed connection/listener settings: '+managed.map(x=>x.id).join(', '));}
 if(tables[0].migrations){const dirty=await sql('SELECT COUNT(*)::int AS count FROM _prisma_migrations WHERE finished_at IS NULL AND rolled_back_at IS NULL');if(dirty[0].count)throw Error('Unresolved Prisma migration; repair explicitly before native predeploy');}
 const redisDeadline=Date.now()+90000;
 for(const db of [0,2,3,4].map(n=>n+Number(process.env.REDIS_SERVER_DATABASE))){let admitted=false;while(Date.now()<redisDeadline){const redis=new Redis({host:process.env.REDIS_SERVER_HOST,port:Number(process.env.REDIS_SERVER_PORT),username:process.env.REDIS_SERVER_USERNAME||undefined,password:process.env.REDIS_SERVER_PASSWORD,db,tls:redisTls(),connectTimeout:5000,maxRetriesPerRequest:0,retryStrategy:()=>null,lazyConnect:true});redis.on('error',()=>{});try{await redis.connect();if(await redis.ping()==='PONG'){admitted=true;break;}}catch{}finally{redis.disconnect();}await delay(1500);}if(!admitted)throw Error('Redis logical database '+db+' failed authenticated TLS/availability admission');}
 // Upstream predeploy uses one DATABASE_URL for two incompatible TLS drivers.
 // Preserve its key format and native migration sequence with explicit per-driver URLs.
 if(!fs.existsSync(configDir+'/private.key'))fs.writeFileSync(configDir+'/private.key',generateKeyPairSync('ec',{namedCurve:'prime256v1'}).privateKey.export({type:'sec1',format:'pem'}),{mode:0o600,flag:'wx'});
 execFileSync(process.execPath,['./node_modules/prisma/build/index.js','migrate','deploy'],{cwd:'/app',env:{...process.env,DATABASE_URL:process.env.HF_PRISMA_URL},stdio:'inherit',timeout:180000});
 execFileSync(process.execPath,['./dist/main.js','run'],{cwd:'/app',env:{...process.env,SERVER_FLAVOR:'script'},stdio:'inherit',timeout:180000});
 const privateKey=fs.readFileSync(configDir+'/private.key','utf8');if(!privateKey.includes('BEGIN EC PRIVATE KEY'))throw Error('Native persistent SEC1 key is required');const parsed=createPrivateKey(privateKey);if(parsed.asymmetricKeyType!=='ec'||parsed.asymmetricKeyDetails.namedCurve!=='prime256v1')throw Error('Unexpected native private key');fs.chmodSync(configDir+'/private.key',0o600);
 if(await prisma.user.count()>0){console.log('Existing identity preserved; private bootstrap HTTP server not started');}
 else{
  const password=fs.readFileSync('/bootstrap-auth/password','utf8');if(password.length<16||password.length>32)throw Error('Initial password must contain 16 to 32 characters');
  child=nativeServer();const readyDeadline=Date.now()+90000;let ready=false;
  while(Date.now()<readyDeadline){if(child.exitCode!==null)throw Error('Native private server exited before setup');try{await initialized();ready=true;break;}catch{await delay(1000);}}
  if(!ready)throw Error('Native private server did not become ready');
  const hexPort=port.toString(16).toUpperCase().padStart(4,'0');const listeners=[];
  for(const file of ['/proc/net/tcp','/proc/net/tcp6'])if(fs.existsSync(file))for(const line of fs.readFileSync(file,'utf8').trim().split('\n').slice(1)){const fields=line.trim().split(/\s+/);if(fields[3]==='0A'&&fields[1].endsWith(':'+hexPort))listeners.push(fields[1]);}
  if(listeners.length!==1||listeners[0]!=='0100007F:'+hexPort)throw Error('Native bootstrap listener is not exclusively IPv4 loopback');
  for(const address of Object.values(networkInterfaces()).flat().filter(x=>x.family==='IPv4'&&!x.internal)){let reachable=false;try{await fetch('http://'+address.address+':'+port+'/info',{signal:AbortSignal.timeout(1000)});reachable=true;}catch{}if(reachable)throw Error('Private bootstrap is reachable through Pod IP');}
  console.log('Native initializer socket verified loopback-only; PodIP HTTP denied');
  if(await initialized())throw Error('Unexpected identity appeared during private setup');
  const response=await fetch('http://127.0.0.1:'+port+'/api/setup/create-admin-user',{method:'POST',headers:{'Content-Type':'application/json',Origin:origin,Host:new URL(origin).host},body:JSON.stringify({name:process.env.BOOTSTRAP_NAME,email:process.env.BOOTSTRAP_EMAIL,password}),signal:AbortSignal.timeout(15000)});
  if(!response.ok){const detail=(await response.text()).replaceAll(password,'[REDACTED]');throw Error('Native first-administrator setup rejected: '+response.status+' '+detail.slice(0,1500));}const user=await response.json();if(user.email!==process.env.BOOTSTRAP_EMAIL||!user.id)throw Error('Native setup returned an unexpected identity');
  if(!await initialized()||!await prisma.userFeature.count({where:{userId:user.id,name:'administrator',activated:true}}))throw Error('Native administrator feature not confirmed');
  await stop();console.log('Native first administrator created privately; signup remains disabled');
 }
 config.server.listenAddr='0.0.0.0';config.metrics.enabled=process.env.HF_METRICS_ENABLED==='true';fs.writeFileSync(configFile,JSON.stringify(config));console.log('Strict migration, pgvector, Redis logical databases and retained native identity admission passed');
}catch(error){await stop();console.error('AFFiNE bootstrap failed: '+String(error.message).replaceAll(process.env.PGPASSWORD,'[REDACTED]').replaceAll(process.env.REDIS_SERVER_PASSWORD,'[REDACTED]'));process.exitCode=1;}finally{await prisma.$disconnect();}
