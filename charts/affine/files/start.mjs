// SPDX-License-Identifier: Apache-2.0
import {spawn} from 'node:child_process';
import {pathToFileURL} from 'node:url';
import {realpathSync,readFileSync} from 'node:fs';
export function environment(){
 const e=process.env;for(const key of ['PGHOST','PGPORT','PGDATABASE','PGUSER','PGPASSWORD','REDIS_SERVER_PASSWORD'])if(!e[key])throw Error('Required dependency configuration is missing: '+key);
 const url=new URL('postgresql://localhost');url.hostname=e.PGHOST;url.port=e.PGPORT;url.username=encodeURIComponent(e.PGUSER);url.password=encodeURIComponent(e.PGPASSWORD);url.pathname='/'+encodeURIComponent(e.PGDATABASE);
 if(e.HF_POSTGRES_TLS==='true'){url.searchParams.set('sslmode','require');url.searchParams.set('sslaccept','strict');if(e.HF_POSTGRES_CA)url.searchParams.set('sslcert',e.HF_POSTGRES_CA);}else url.searchParams.set('sslmode','disable');e.HF_PRISMA_URL=url.toString();
 if(e.HF_POSTGRES_TLS==='true'){url.search='';url.searchParams.set('sslmode','verify-full');if(e.HF_POSTGRES_CA)url.searchParams.set('sslrootcert',e.HF_POSTGRES_CA);}e.DATABASE_URL=url.toString();
}
export function redisTls(){return process.env.HF_REDIS_TLS==='true'?{servername:process.env.REDIS_SERVER_HOST,rejectUnauthorized:true,...(process.env.HF_REDIS_CA?{ca:readFileSync(process.env.HF_REDIS_CA,'utf8')}:{})}:undefined;}
export function nativeServer(){return spawn(process.execPath,['./dist/main.js'],{cwd:'/app',env:process.env,stdio:'inherit'});}
if(process.argv[1]&&import.meta.url===pathToFileURL(realpathSync(process.argv[1])).href){
 environment();const child=nativeServer();for(const signal of ['SIGTERM','SIGINT'])process.on(signal,()=>child.kill(signal));child.on('error',()=>{console.error('Native AFFiNE server failed to start');process.exit(1);});child.on('exit',(code,signal)=>process.exit(code??(signal==='SIGTERM'?0:1)));
}
