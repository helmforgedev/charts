// SPDX-License-Identifier: Apache-2.0
import assert from "node:assert/strict";
import { createHash } from "node:crypto";

const sha = (bytes) => createHash("sha256").update(bytes).digest("hex");
export async function verifyUpload({ request, upload }) {
  const response = await request(upload.path, { anonymous: true });
  assert.equal(response.status, 200, "Native public picture delivery failed");
  assert.equal(sha(Buffer.from(await response.arrayBuffer())), upload.hash);
}

export async function uploadSmoke({ values, k, pod, request, origin }) {
  // A valid tiny PNG exercises native Sharp decoding and JPEG transformation.
  const bytes = Buffer.from(
    k([
      "exec",
      pod(),
      "-c",
      "reactive-resume",
      "--",
      "node",
      "-e",
      "const native=require('node:module').createRequire('/app/apps/server/package.json');native('sharp')({create:{width:32,height:24,channels:3,background:{r:32,g:96,b:160}}}).png().toBuffer().then(bytes=>console.log(bytes.toString('base64')));",
    ]).trim(),
    "base64",
  );
  const body = new FormData();
  body.set("data", JSON.stringify({ json: {}, maps: [[]] }));
  body.set("0", new File([bytes], "owned-picture.png", { type: "image/png" }));
  const rejected = await request("/api/rpc/storage/uploadFile", {
    method: "POST",
    body,
    anonymous: true,
  });
  assert.ok(
    [401, 403].includes(rejected.status),
    "Anonymous native uploads must fail",
  );
  const uploaded = await request("/api/rpc/storage/uploadFile", {
    method: "POST",
    body,
  });
  assert.equal(uploaded.status, 200, "Native picture upload failed");
  const envelope = await uploaded.json();
  const result = envelope.json;
  assert.equal(result.contentType, "image/jpeg");
  const url = new URL(result.url);
  assert.equal(url.origin, origin);
  assert.match(result.path, /^uploads\/[^/]+\/pictures\/[^/]+\.jpeg$/);
  const download = await request(url.pathname, { anonymous: true });
  assert.equal(download.status, 200);
  const image = Buffer.from(await download.arrayBuffer());
  assert.equal(image.subarray(0, 2).toString("hex"), "ffd8");
  const upload = { path: url.pathname, hash: sha(image) };
  if (values.storage.driver === "s3") {
    const script = `
      const assert=require('node:assert/strict'); const fs=require('node:fs');
      const https=require('node:https'); const tls=require('node:tls');
      const {createHash}=require('node:crypto');
      const {createRequire}=require('node:module');
      const native=createRequire('/app/apps/server/package.json');
      const {S3Client,GetObjectCommand}=native('@aws-sdk/client-s3');
      (async()=>{
        const endpoint=new URL(process.env.S3_ENDPOINT);
        const ca=fs.readFileSync('/s3-ca/ca.crt');
        const make=(agent)=>new S3Client({
          endpoint:endpoint.toString(),region:process.env.S3_REGION,
          forcePathStyle:process.env.S3_FORCE_PATH_STYLE==='true',maxAttempts:1,
          credentials:{accessKeyId:process.env.S3_ACCESS_KEY_ID,secretAccessKey:process.env.S3_SECRET_ACCESS_KEY},
          requestHandler:{httpsAgent:agent,connectionTimeout:4000,requestTimeout:6000}
        });
        const read=async(options)=>{
          const client=make(new https.Agent({ca,rejectUnauthorized:true,...options}));
          try { const response=await client.send(new GetObjectCommand({Bucket:process.env.S3_BUCKET,Key:${JSON.stringify(result.path)}}));
            return Buffer.from(await response.Body.transformToByteArray());
          }finally{client.destroy();}
        };
        assert.equal(createHash('sha256').update(await read({})).digest('hex'),${JSON.stringify(upload.hash)});
        await assert.rejects(()=>read({ca:tls.rootCertificates}),/certificate|issuer|self.signed/i);
        await assert.rejects(()=>read({servername:'wrong-host.example.test'}),/hostname|altnames|certificate/i);
        const unsigned=new URL(endpoint);unsigned.pathname='/'+process.env.S3_BUCKET+'/'+${JSON.stringify(result.path)};
        const status=await new Promise((resolve,reject)=>{
          const req=https.get(unsigned,{ca,rejectUnauthorized:true,timeout:5000},res=>{res.resume();resolve(res.statusCode)});
          req.on('error',reject);req.on('timeout',()=>req.destroy(Error('request timeout')));
        });
        assert.equal(status,403);
        assert.equal(createHash('sha256').update(await read({})).digest('hex'),${JSON.stringify(upload.hash)});
        console.log('PASS signed bucket bytes, unsigned denial, unknown CA and hostname rejection');
      })().catch(()=>{console.error('S3 fixture acceptance failed');process.exitCode=1});
    `;
    assert.match(
      k(["exec", pod(), "-c", "reactive-resume", "--", "node", "-e", script]),
      /PASS signed bucket bytes/,
    );
  }
  console.log(
    "PASS native authenticated picture upload, image processing and public delivery hash",
  );
  return upload;
}
