// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import fs from 'node:fs';
import net from 'node:net';
const env=process.env,host=env.DB_HOST.replace(/^\[|\]$/g,''),port=Number(env.DB_PORT);
assert.ok(host&&Number.isInteger(port)&&port>0&&port<=65535);
const address=net.isIP(host)===6?'['+host+']':host;
const password=fs.readFileSync('/database-auth/password','utf8');
const query=new URLSearchParams();let dsn;
if(env.MEMOS_DRIVER==='postgres'){
 query.set('sslmode',env.DB_SSL_MODE);query.set('connect_timeout','10');
 if(env.DB_HAS_CA==='true')query.set('sslrootcert','/database-ca/ca.crt');
 dsn=`postgres://${encodeURIComponent(env.DB_USER)}:${encodeURIComponent(password)}@${address}:${port}/${encodeURIComponent(env.DB_NAME)}?${query}`;
}else{
 assert.equal(env.MEMOS_DRIVER,'mysql');assert.ok(!env.DB_USER.includes(':'),'MySQL DSN user cannot contain colon');
 query.set('charset','utf8mb4');query.set('parseTime','true');query.set('loc','UTC');query.set('tls',env.DB_MYSQL_TLS);query.set('timeout','10s');
 // go-sql-driver/mysql separates credentials at the last @. Its password is not URI-encoded.
 dsn=`${env.DB_USER}:${password}@tcp(${address}:${port})/${encodeURIComponent(env.DB_NAME)}?${query}`;
}
fs.writeFileSync('/database-runtime/dsn',dsn,{mode:0o600});
const deadline=Date.now()+Number(env.DB_CONNECTION_TIMEOUT)*1000;let available=false;
while(Date.now()<deadline){available=await new Promise(resolve=>{const socket=net.createConnection({host,port});let finished=false;const done=value=>{if(finished)return;finished=true;socket.destroy();resolve(value);};socket.setTimeout(2000);socket.once('connect',()=>done(true));socket.once('error',()=>done(false));socket.once('timeout',()=>done(false));});if(available)break;await new Promise(r=>setTimeout(r,1000));}
assert.ok(available,'Database TCP endpoint did not become available before startup deadline');
console.log('Database connection file prepared; native Memos startup will verify authentication and migrations');
