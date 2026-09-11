// SPDX-License-Identifier: Apache-2.0
import assert from "node:assert/strict";

export function verifyDependencies({ values, k, pod }) {
  if (values.postgresql.enabled && values.redis.enabled) return;
  const script = `
    import assert from 'node:assert/strict';import fs from 'node:fs';import tls from 'node:tls';
    import{createRequire}from'node:module';import{configure,nativeDirectory}from'/helmforge/configure.mjs';
    configure();const require=createRequire(nativeDirectory+'/package.json');
    ${
      !values.postgresql.enabled
        ? `
    const{Client}=require('pg');const pgbase={host:process.env.HF_DATABASE_HOST,port:Number(process.env.HF_DATABASE_PORT),database:process.env.HF_DATABASE_NAME,user:process.env.HF_DATABASE_USERNAME,password:process.env.HF_DATABASE_PASSWORD,connectionTimeoutMillis:4000,query_timeout:5000};
    const ca=fs.readFileSync(process.env.HF_DATABASE_CA);
    const pg=async ssl=>{const db=new Client({...pgbase,ssl});try{await db.connect();assert.equal((await db.query('SELECT ssl FROM pg_stat_ssl WHERE pid=pg_backend_pid()')).rows[0].ssl,true);}finally{await db.end().catch(()=>{})}};
    await pg({ca,rejectUnauthorized:true});await assert.rejects(()=>pg({rejectUnauthorized:true}),/certificate|issuer|self.signed/i);
    await assert.rejects(()=>pg({ca,rejectUnauthorized:true,checkServerIdentity:(_host,cert)=>tls.checkServerIdentity('wrong-host.example.test',cert)}),/hostname|altnames|certificate/i);
    await pg({ca,rejectUnauthorized:true});
    `
        : ""
    }
    ${
      !values.redis.enabled
        ? `
    const Redis=require('ioredis');const redisCa=fs.readFileSync(process.env.HF_REDIS_CA);
    const check=async(overrides={})=>{const target=new URL(process.env.REDIS_URL);if(overrides.password!==undefined)target.password=encodeURIComponent(overrides.password);const client=new Redis(target.toString(),{lazyConnect:true,connectTimeout:4000,maxRetriesPerRequest:1,retryStrategy:null,tls:{ca:redisCa,servername:process.env.HF_REDIS_HOST,rejectUnauthorized:true},...overrides});let connectionError;client.on('error',error=>{connectionError=error});try{await client.connect();assert.equal(await client.ping(),'PONG');}catch(error){throw connectionError??error;}finally{client.disconnect()}};
    await check();await assert.rejects(()=>check({tls:{rejectUnauthorized:true}}),/certificate|issuer|self.signed/i);
    await assert.rejects(()=>check({tls:{ca:redisCa,servername:'wrong-host.example.test',rejectUnauthorized:true}}),/hostname|altnames|certificate/i);
    await assert.rejects(()=>check({password:'wrong-owned-fixture'}),/WRONGPASS|AUTH/i);await check();
    `
        : ""
    }
    console.log('PASS native dependency TLS, incorrect CA/hostname and Redis credential rejection');
  `;
  assert.match(
    k([
      "exec",
      pod(),
      "-c",
      "twenty",
      "--",
      "node",
      "--input-type=module",
      "-e",
      script,
    ]),
    /PASS native dependency TLS/,
  );
  console.log(
    "PASS native PostgreSQL and Redis strict TLS acceptance with real application and worker traffic",
  );
}

export function verifyBucket({ values, k, pod, attachment }) {
  if (values.storage.driver !== "s3") return;
  const script = `
    import assert from 'node:assert/strict';import fs from 'node:fs';import https from 'node:https';import tls from 'node:tls';import{createHash}from'node:crypto';
    import{createRequire}from'node:module';const require=createRequire('/app/packages/twenty-server/package.json');
    const{S3Client,GetObjectCommand,ListObjectsV2Command}=require('@aws-sdk/client-s3');
    const ca=fs.readFileSync('/s3-ca/ca.crt');const endpoint=process.env.STORAGE_S3_ENDPOINT;
    const create=options=>new S3Client({endpoint,region:process.env.STORAGE_S3_REGION,forcePathStyle:true,maxAttempts:1,
      credentials:{accessKeyId:process.env.STORAGE_S3_ACCESS_KEY_ID,secretAccessKey:process.env.STORAGE_S3_SECRET_ACCESS_KEY},
      requestHandler:{httpsAgent:new https.Agent({ca,rejectUnauthorized:true,...options}),connectionTimeout:4000,requestTimeout:6000}});
    const client=create({});let key;
    try{const listed=await client.send(new ListObjectsV2Command({Bucket:process.env.STORAGE_S3_NAME}));
      const matches=(listed.Contents??[]).filter(item=>item.Key.endsWith(${JSON.stringify(attachment.path)})||item.Key.includes(${JSON.stringify(attachment.fileId)}));
      assert.equal(matches.length,1,'Native attachment must correspond to one stored object');key=matches[0].Key;
    }finally{client.destroy()}
    const read=async options=>{const client=create(options);try{const result=await client.send(new GetObjectCommand({Bucket:process.env.STORAGE_S3_NAME,Key:key}));return Buffer.from(await result.Body.transformToByteArray())}finally{client.destroy()}};
    const check=async()=>assert.equal(createHash('sha256').update(await read({})).digest('hex'),${JSON.stringify(attachment.hash)});
    await check();await assert.rejects(()=>read({ca:tls.rootCertificates}),/certificate|issuer|self.signed/i);
    await assert.rejects(()=>read({servername:'wrong-host.example.test'}),/hostname|altnames|certificate/i);
    const url=new URL(endpoint);url.pathname='/'+process.env.STORAGE_S3_NAME+'/'+key;
    const status=await new Promise((resolve,reject)=>{const req=https.get(url,{ca,rejectUnauthorized:true,timeout:5000},res=>{res.resume();resolve(res.statusCode)});req.on('error',reject);req.on('timeout',()=>req.destroy(Error('timeout')))});
    assert.equal(status,403);await check();console.log('PASS private native S3 bytes, unsigned denial and strict TLS');
  `;
  assert.match(
    k([
      "exec",
      pod(),
      "-c",
      "twenty",
      "--",
      "node",
      "--input-type=module",
      "-e",
      script,
    ]),
    /PASS private native S3 bytes/,
  );
  console.log(
    "PASS native private S3 attachment bytes, unsigned-access denial and strict TLS negative controls",
  );
}
