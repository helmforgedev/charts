// SPDX-License-Identifier: Apache-2.0
import assert from "node:assert/strict";

export function databaseSmoke({ values, k, pod }) {
  if (values.postgresql.enabled || !values.database.tls.enabled) return;
  const script = `
    const assert=require('node:assert/strict');const fs=require('node:fs');
    const {Client}=require('node:module').createRequire('/app/apps/server/package.json')('pg');
    const ca=fs.readFileSync(process.env.HF_DATABASE_CA);
    const config={host:process.env.HF_DATABASE_HOST,port:Number(process.env.HF_DATABASE_PORT),
      database:process.env.HF_DATABASE_NAME,user:process.env.HF_DATABASE_USERNAME,
      password:process.env.HF_DATABASE_PASSWORD,connectionTimeoutMillis:4000,query_timeout:5000};
    async function query(ssl){const client=new Client({...config,ssl});try{await client.connect();
      const row=(await client.query('SELECT ssl FROM pg_stat_ssl WHERE pid=pg_backend_pid()')).rows[0];
      assert.equal(row.ssl,true);
    }finally{await client.end().catch(()=>{})}}
    (async()=>{await query({ca,rejectUnauthorized:true});
      await assert.rejects(()=>query({rejectUnauthorized:true}),/certificate|issuer|self.signed/i);
      await assert.rejects(()=>query({ca,rejectUnauthorized:true,checkServerIdentity:(_host,cert)=>require('node:tls').checkServerIdentity('wrong-host.example.test',cert)}),/hostname|altnames|certificate/i);
      await query({ca,rejectUnauthorized:true});console.log('PASS PostgreSQL TLS active, untrusted CA and wrong hostname rejected');
    })().catch(()=>{console.error('PostgreSQL strict TLS acceptance failed');process.exitCode=1});
  `;
  assert.match(
    k(["exec", pod(), "-c", "reactive-resume", "--", "node", "-e", script]),
    /PASS PostgreSQL TLS active/,
  );
}
