// SPDX-License-Identifier: Apache-2.0
import assert from "node:assert/strict";
import { execFileSync, spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { verifyIsolation } from "./isolation-smoke.mjs";
import { attachmentSmoke, verifyAttachment } from "./file-smoke.mjs";
import { verifyDependencies, verifyBucket } from "./integrations-smoke.mjs";
import { smtpSmoke } from "./smtp-smoke.mjs";
import { verifyMetrics } from "./metrics-smoke.mjs";
import { browserSmoke } from "./browser-smoke.mjs";
import { restoreSmoke } from "./restore-smoke.mjs";

const [context, namespace, release] = process.argv.slice(2);
assert.equal(context, "k3d-helmforge-tests-wsl");
assert.equal(namespace, "hf-validate-twenty");
const k = (args) =>
  execFileSync("kubectl", ["--context", context, "-n", namespace, ...args], {
    encoding: "utf8",
    timeout: 120000,
  });
const values = JSON.parse(
  execFileSync(
    "helm",
    [
      "get",
      "values",
      release,
      "--kube-context",
      context,
      "-n",
      namespace,
      "-a",
      "-o",
      "json",
    ],
    {
      encoding: "utf8",
    },
  ),
);
const selector =
  "app.kubernetes.io/instance=" +
  release +
  ",app.kubernetes.io/name=" +
  (values.nameOverride || "twenty");
const deployment = JSON.parse(
  k(["get", "deployment", "-l", selector, "-o", "json"]),
).items[0];
const pod = () =>
  JSON.parse(k(["get", "pods", "-l", selector, "-o", "json"])).items.find(
    (p) => !p.metadata.deletionTimestamp,
  ).metadata.name;
const bootstrapSecret = deployment.spec.template.spec.volumes.find(
  (v) => v.name === "bootstrap-auth",
).secret.secretName;
const password = Buffer.from(
  JSON.parse(k(["get", "secret", bootstrapSecret, "-o", "json"])).data[
    values.bootstrap.passwordKey
  ],
  "base64",
).toString();
const origin =
  values.server.publicUrl ||
  "http://" +
    deployment.metadata.name +
    "." +
    namespace +
    ".svc:" +
    values.service.port;
const identityName = deployment.spec.template.spec.containers[0].env.find(
  (e) => e.name === "SERVER_ID",
).valueFrom.secretKeyRef.name;
const identity = () =>
  JSON.stringify(
    Object.entries(
      JSON.parse(k(["get", "secret", identityName, "-o", "json"])).data,
    ).sort(),
  );
const originalIdentity = identity();
let currentPassword = password;
if (values.fullnameOverride === "twenty-production") {
  const pods = JSON.parse(
    k([
      "get",
      "pods",
      "-l",
      "app.kubernetes.io/instance=" + release,
      "-o",
      "json",
    ]),
  ).items;
  assert.ok(pods.length >= 4);
  for (const item of pods) {
    assert.equal(item.spec.serviceAccountName, values.serviceAccount.name);
    const account = JSON.parse(
      k(["get", "serviceaccount", item.spec.serviceAccountName, "-o", "json"]),
    );
    assert.equal(
      item.spec.automountServiceAccountToken ??
        account.automountServiceAccountToken,
      false,
    );
    assert.ok(
      !(item.spec.volumes ?? []).some((volume) =>
        volume.projected?.sources?.some((source) => source.serviceAccountToken),
      ),
    );
  }
  console.log(
    "PASS application, admission helper, PostgreSQL and Redis use tokenless Pods",
  );
}
let token, workspaceId, companyId, attachment;
const marker = "HelmForge CRM " + randomUUID();
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
async function forward(action, remotePort = 3000, target) {
  const pf = spawn(
    "kubectl",
    [
      "--context",
      context,
      "-n",
      namespace,
      "port-forward",
      target || "pod/" + pod(),
      "0:" + remotePort,
      "--address=127.0.0.1",
    ],
    { windowsHide: true, stdio: ["ignore", "pipe", "pipe"] },
  );
  let output = "";
  for (const stream of [pf.stdout, pf.stderr])
    stream.on("data", (chunk) => (output += chunk));
  try {
    const deadline = Date.now() + 15000;
    while (
      !/Forwarding from/.test(output) &&
      Date.now() < deadline &&
      pf.exitCode === null
    )
      await sleep(100);
    const port = output.match(/127\.0\.0\.1:(\d+)/)?.[1];
    assert.ok(port, "Owned application forwarding unavailable");
    await action("http://127.0.0.1:" + port);
  } finally {
    if (pf.exitCode === null && pf.signalCode === null) {
      if (process.platform === "win32")
        execFileSync("taskkill", ["/PID", String(pf.pid), "/T", "/F"], {
          stdio: "ignore",
        });
      else pf.kill();
    }
  }
}
async function graphql(
  base,
  query,
  variables = {},
  bearer = token,
  path = "/metadata",
  allowErrors = false,
) {
  const response = await fetch(base + path, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Origin: origin,
      Host: new URL(origin).host,
      ...(bearer ? { Authorization: "Bearer " + bearer } : {}),
    },
    body: JSON.stringify({ query, variables }),
    signal: AbortSignal.timeout(15000),
  });
  const result = await response.json();
  if (allowErrors) return { status: response.status, ...result };
  assert.equal(response.status, 200);
  assert.ok(
    !result.errors?.length,
    "Native GraphQL operation failed: " +
      JSON.stringify(
        result.errors?.map((error) => ({
          message: error.message,
          code: error.extensions?.code,
        })),
      ),
  );
  return result.data;
}
async function login(base) {
  const data = await graphql(
    base,
    "mutation($email:String!,$password:String!){signIn(email:$email,password:$password){availableWorkspaces{availableWorkspacesForSignIn{id loginToken}}}}",
    { email: values.bootstrap.email, password: currentPassword },
    null,
  );
  const available =
    data.signIn.availableWorkspaces.availableWorkspacesForSignIn;
  assert.equal(available.length, 1);
  if (workspaceId) assert.equal(available[0].id, workspaceId);
  workspaceId = available[0].id;
  const exchanged = await graphql(
    base,
    "mutation($loginToken:String!,$origin:String!){getAuthTokensFromLoginToken(loginToken:$loginToken,origin:$origin){tokens{accessOrWorkspaceAgnosticToken{token}}}}",
    { loginToken: available[0].loginToken, origin },
    null,
  );
  token =
    exchanged.getAuthTokensFromLoginToken.tokens.accessOrWorkspaceAgnosticToken
      .token;
}
function nativeUserCount() {
  return Number(
    k([
      "exec",
      pod(),
      "-c",
      "twenty",
      "--",
      "node",
      "--input-type=module",
      "-e",
      "import{createRequire}from'node:module';import{configure,nativeDirectory}from'/helmforge/configure.mjs';configure();const{Client}=createRequire(nativeDirectory+'/package.json')('pg');const db=new Client({connectionString:process.env.PG_DATABASE_URL,connectionTimeoutMillis:4000,query_timeout:5000});try{await db.connect();console.log((await db.query('SELECT count(*) AS count FROM core.\\\"user\\\"')).rows[0].count);}finally{await db.end();}",
    ]).trim(),
  );
}
function workerProof() {
  const script = `
    import assert from 'node:assert/strict';import fs from 'node:fs';import path from 'node:path';
    import {createRequire}from'node:module';import{configure,nativeDirectory}from'/helmforge/configure.mjs';
    configure();const require=createRequire(nativeDirectory+'/package.json'),Redis=require('ioredis'),{Queue}=require('bullmq'),{Client}=require('pg');
    const redis=new Redis(process.env.REDIS_URL,{connectTimeout:3000,maxRetriesPerRequest:1,retryStrategy:null,...(process.env.HF_REDIS_TLS==='true'?{tls:{ca:fs.readFileSync(process.env.HF_REDIS_CA),servername:process.env.HF_REDIS_HOST,rejectUnauthorized:true}}:{})});redis.on('error',()=>{});
    const queue=new Queue('workspace-queue',{connection:redis});const pg=new Client({connectionString:process.env.PG_DATABASE_URL,connectionTimeoutMillis:4000,query_timeout:5000});
    const walk=dir=>fs.existsSync(dir)?fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?walk(path.join(dir,e.name)):[path.join(dir,e.name)]):[];
    try{await pg.connect();const deadline=Date.now()+60000;let proven=false;
      while(Date.now()<deadline){
        const jobs=await queue.getJobs(['completed'],0,199);
        const job=jobs.find(j=>j.data?.workspaceId===${JSON.stringify(workspaceId)}&&j.data?.applicationId&&/sdk/i.test(j.name));
        if(job){const app=(await pg.query('SELECT "sdkClientCoreChecksum" FROM core.application WHERE id=$1 AND "workspaceId"=$2',[job.data.applicationId,job.data.workspaceId])).rows[0];
          let zip;
          if(process.env.HF_STORAGE_DRIVER==='s3'){
            const{S3Client,ListObjectsV2Command,GetObjectCommand}=require('@aws-sdk/client-s3');const https=require('node:https');
            const client=new S3Client({endpoint:process.env.STORAGE_S3_ENDPOINT,region:process.env.STORAGE_S3_REGION,forcePathStyle:true,maxAttempts:1,credentials:{accessKeyId:process.env.STORAGE_S3_ACCESS_KEY_ID,secretAccessKey:process.env.STORAGE_S3_SECRET_ACCESS_KEY},requestHandler:{httpsAgent:new https.Agent({ca:fs.readFileSync('/s3-ca/ca.crt'),rejectUnauthorized:true}),connectionTimeout:4000,requestTimeout:6000}});
            try{const listed=await client.send(new ListObjectsV2Command({Bucket:process.env.STORAGE_S3_NAME}));const archive=listed.Contents?.find(item=>item.Key.endsWith('twenty-client-sdk.zip')&&item.Key.includes(job.data.workspaceId)&&item.Key.includes(job.data.applicationUniversalIdentifier));if(archive){const response=await client.send(new GetObjectCommand({Bucket:process.env.STORAGE_S3_NAME,Key:archive.Key}));zip=Buffer.from(await response.Body.transformToByteArray());}}finally{client.destroy()}
          }else{const archives=walk('/app/data/storage').filter(p=>p.endsWith('twenty-client-sdk.zip')&&p.includes(job.data.workspaceId)&&p.includes(job.data.applicationUniversalIdentifier));if(archives.length)zip=fs.readFileSync(archives[0]);}
          if(app&&/^[a-f0-9]{64}$/.test(app.sdkClientCoreChecksum)&&zip){assert.equal(zip.subarray(0,2).toString(),'PK');assert.ok(zip.length>1000);proven=true;break;}
        }await new Promise(r=>setTimeout(r,1000));
      }assert.ok(proven,'Native SDK generation job did not produce its recorded checksum and stored archive');
      console.log('PASS completed native workspace SDK job, application checksum and stored ZIP');
    }finally{await pg.end().catch(()=>{});await queue.close();redis.disconnect();}
  `;
  assert.match(
    k([
      "exec",
      pod(),
      "-c",
      "worker",
      "--",
      "node",
      "--input-type=module",
      "-e",
      script,
    ]),
    /PASS completed native workspace SDK job/,
  );
}
try {
  verifyIsolation({ context, namespace, release, k, deployment, pod, values });
  verifyDependencies({ values, k, pod });
  await forward(async (base) => {
    assert.equal((await fetch(base + "/healthz")).status, 200);
    const userCount = nativeUserCount();
    assert.ok(userCount >= 1);
    const denied = await graphql(
      base,
      "mutation($email:String!,$password:String!){signUp(email:$email,password:$password){tokens{accessOrWorkspaceAgnosticToken{token}}}}",
      {
        email: "uninvited-" + randomUUID() + "@example.test",
        password: "Owned-Uninvited-2026",
      },
      null,
      "/metadata",
      true,
    );
    assert.ok(
      denied.errors?.length,
      "Uninvited native signup must fail after workspace initialization",
    );
    assert.equal(
      nativeUserCount(),
      userCount,
      "Rejected signup must not persist an uninvited user",
    );
    await login(base);
    const created = await graphql(
      base,
      "mutation($data:CompanyCreateInput!){createCompany(data:$data){id name}}",
      { data: { name: marker } },
      token,
      "/graphql",
    );
    companyId = created.createCompany.id;
    assert.equal(created.createCompany.name, marker);
    attachment = await attachmentSmoke({
      base,
      origin,
      graphql,
      token,
      companyId,
    });
    verifyBucket({ values, k, pod, attachment });
    const anonymous = await graphql(
      base,
      "mutation($data:CompanyCreateInput!){createCompany(data:$data){id name}}",
      { data: { name: "Forbidden anonymous company" } },
      null,
      "/graphql",
      true,
    );
    assert.ok(anonymous.errors?.length || anonymous.status === 401);
    workerProof();
    currentPassword = await smtpSmoke({
      context,
      namespace,
      values,
      k,
      pod,
      graphql,
      base,
      origin,
      password: currentPassword,
    });
    if (values.smtp.enabled) await login(base);
    if (values.fullnameOverride === "twenty-browser")
      await browserSmoke({
        base,
        origin,
        email: values.bootstrap.email,
        password: currentPassword,
        marker,
        companyId,
      });
    console.log(
      "PASS native administrator login, closed uninvited signup, company creation and real worker job output",
    );
  });
  if (values.metrics.enabled)
    await verifyMetrics({ k, forward, values, namespace, context, deployment });
  if (values.fullnameOverride === "twenty-restore") {
    restoreSmoke({
      context,
      namespace,
      release,
      k,
      values,
      deployment,
      pod,
      workspaceId,
    });
  } else k(["rollout", "restart", "deployment/" + deployment.metadata.name]);
  k([
    "rollout",
    "status",
    "deployment/" + deployment.metadata.name,
    "--timeout=120s",
  ]);
  await forward(async (base) => {
    const response = await fetch(base + "/rest/companies/" + companyId, {
      headers: {
        Authorization: "Bearer " + token,
        Origin: origin,
        Host: new URL(origin).host,
      },
      signal: AbortSignal.timeout(15000),
    });
    assert.equal(
      response.status,
      200,
      "Original signed session must survive replacement",
    );
    const record = await response.json();
    const containsCompany = (value) =>
      value &&
      typeof value === "object" &&
      ((value.id === companyId && value.name === marker) ||
        Object.values(value).some(containsCompany));
    assert.ok(
      containsCompany(record),
      "Native company content must survive replacement",
    );
    await login(base);
    await verifyAttachment({ base, origin, token, attachment });
  });
  assert.equal(identity(), originalIdentity);
  console.log(
    "PASS retained native administrator, workspace, encryption identity, session and company after Pod replacement",
  );
} catch (error) {
  console.error(
    String(error.stack ?? error)
      .replaceAll(password, "[REDACTED]")
      .replaceAll(currentPassword, "[REDACTED]")
      .replaceAll(token || "no-token-value", "[REDACTED]"),
  );
  throw Error("Twenty behavioral validation failed");
}
