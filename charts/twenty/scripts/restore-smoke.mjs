// SPDX-License-Identifier: Apache-2.0
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { randomUUID } from "node:crypto";

export function restoreSmoke({
  context,
  namespace,
  release,
  k,
  values,
  deployment,
  pod,
  workspaceId,
}) {
  assert.equal(context, "k3d-helmforge-tests-wsl");
  assert.equal(namespace, "hf-validate-twenty");
  assert.equal(deployment.metadata.name, "twenty-restore");
  assert.equal(values.storage.driver, "local");
  assert.equal(values.postgresql.enabled, true);
  assert.equal(values.redis.enabled, true);
  const queuedId = "hf-recovery-" + randomUUID(),
    recoveryStart = Date.now();
  const queueSetup =
    "import assert from 'node:assert/strict';import{createRequire}from'node:module';import{configure,nativeDirectory}from'/helmforge/configure.mjs';configure();const require=createRequire(nativeDirectory+'/package.json'),Redis=require('ioredis'),{Queue}=require('bullmq');const redis=new Redis(process.env.REDIS_URL,{connectTimeout:4000,maxRetriesPerRequest:1,retryStrategy:null});redis.on('error',()=>{});const queue=new Queue('workspace-queue',{connection:redis});";
  const queued = k([
    "exec",
    pod(),
    "-c",
    "worker",
    "--",
    "node",
    "--input-type=module",
    "-e",
    queueSetup +
      `
    try{const original=(await queue.getJobs(['completed'],0,199)).find(job=>job.data?.workspaceId===${JSON.stringify(workspaceId)}&&job.data?.applicationId&&/sdk/i.test(job.name));assert.ok(original);
    const job=await queue.add(original.name,original.data,{jobId:${JSON.stringify(queuedId)},delay:600000,removeOnComplete:false,removeOnFail:false});assert.equal(await job.getState(),'delayed');console.log('owned native SDK recovery job persisted');}
    finally{await queue.close();redis.disconnect();}`,
  ]);
  assert.match(queued, /owned native SDK recovery job persisted/);
  const appPod = pod(),
    appClaim = deployment.spec.template.spec.volumes.find(
      (v) => v.name === "data",
    ).persistentVolumeClaim.claimName;
  k(["scale", "deployment/" + deployment.metadata.name, "--replicas=0"]);
  k(["wait", "--for=delete", "pod/" + appPod, "--timeout=60s"]);
  const dependency = (name) =>
    JSON.parse(
      k([
        "get",
        "pods",
        "-l",
        "app.kubernetes.io/name=" +
          name +
          ",app.kubernetes.io/instance=" +
          release,
        "-o",
        "json",
      ]),
    ).items[0];
  const pg = dependency("postgresql"),
    redis = dependency("redis");
  assert.ok(pg && redis);
  const databaseScript = `set -euo pipefail
    umask 077
    export PGPASSWORD="$APP_PASSWORD"
    pg_dump -h 127.0.0.1 -U "$APP_USERNAME" -d "$APP_DATABASE" -Fc -f /tmp/twenty.dump
    export PGPASSWORD="$POSTGRES_PASSWORD"
    createdb -h 127.0.0.1 -U "$POSTGRES_USER" --owner="$APP_USERNAME" twenty_recovered
    pg_restore -h 127.0.0.1 -U "$POSTGRES_USER" -d twenty_recovered --exit-on-error --no-owner --no-privileges --role="$APP_USERNAME" /tmp/twenty.dump
    rm /tmp/twenty.dump
    echo owned-twenty-database-recovered`;
  assert.match(
    k([
      "exec",
      pg.metadata.name,
      "-c",
      pg.spec.containers[0].name,
      "--",
      "bash",
      "-ceu",
      databaseScript,
    ]),
    /owned-twenty-database-recovered/,
  );
  const redisOwner = redis.metadata.ownerReferences.find(
    (owner) => owner.kind === "StatefulSet",
  );
  assert.ok(redisOwner);
  const redisSts = JSON.parse(
    k(["get", "statefulset", redisOwner.name, "-o", "json"]),
  );
  const redisDataMount = redis.spec.containers[0].volumeMounts.find(
    (mount) => mount.mountPath === "/data",
  );
  assert.ok(redisDataMount);
  const redisClaim = redis.spec.volumes.find(
    (volume) => volume.name === redisDataMount.name,
  ).persistentVolumeClaim.claimName;
  k(["scale", "statefulset/" + redisOwner.name, "--replicas=0"]);
  k(["wait", "--for=delete", "pod/" + redis.metadata.name, "--timeout=60s"]);
  const apply = (doc) =>
    execFileSync(
      "kubectl",
      ["--context", context, "-n", namespace, "apply", "-f", "-"],
      {
        input: JSON.stringify(doc),
        encoding: "utf8",
        timeout: 15000,
      },
    );
  function copyClaim(
    source,
    name,
    securityContext,
    containerSecurityContext,
    assertion,
  ) {
    const old = JSON.parse(k(["get", "pvc", source, "-o", "json"]));
    apply({
      apiVersion: "v1",
      kind: "PersistentVolumeClaim",
      metadata: { name },
      spec: {
        accessModes: old.spec.accessModes,
        storageClassName: old.spec.storageClassName,
        resources: old.spec.resources,
      },
    });
    const copier = name + "-copy";
    apply({
      apiVersion: "v1",
      kind: "Pod",
      metadata: {
        name: copier,
        labels: { "helmforge.dev/runtime-fixture": "true" },
      },
      spec: {
        restartPolicy: "Never",
        automountServiceAccountToken: false,
        securityContext,
        containers: [
          {
            name: "restore",
            image: pg.spec.containers[0].image,
            command: [
              "bash",
              "-ceu",
              "set -o pipefail; umask 077; cd /source; find . -mindepth 1 -maxdepth 1 -print0 | tar --null -T - -czf /tmp/owned-state.tar.gz; tar --no-same-owner --no-overwrite-dir -xzf /tmp/owned-state.tar.gz -C /recovered; " +
                assertion +
                "; echo owned-state-recovered",
            ],
            securityContext: containerSecurityContext,
            resources: {
              requests: { cpu: "50m", memory: "64Mi" },
              limits: { cpu: "500m", memory: "256Mi" },
            },
            volumeMounts: [
              { name: "source", mountPath: "/source", readOnly: true },
              { name: "recovered", mountPath: "/recovered" },
              { name: "tmp", mountPath: "/tmp" },
            ],
          },
        ],
        volumes: [
          { name: "source", persistentVolumeClaim: { claimName: source } },
          { name: "recovered", persistentVolumeClaim: { claimName: name } },
          { name: "tmp", emptyDir: { sizeLimit: "1Gi" } },
        ],
      },
    });
    const deadline = Date.now() + 60000;
    let phase;
    do {
      phase = JSON.parse(k(["get", "pod", copier, "-o", "json"])).status.phase;
      if (phase === "Succeeded" || phase === "Failed") break;
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 500);
    } while (Date.now() < deadline);
    const logs = k(["logs", copier]);
    assert.equal(phase, "Succeeded", "Owned recovery helper failed: " + logs);
    assert.match(logs, /owned-state-recovered/);
    k(["delete", "pod/" + copier, "--wait=true", "--timeout=30s"]);
    assert.notEqual(
      JSON.parse(k(["get", "pvc", name, "-o", "json"])).metadata.uid,
      old.metadata.uid,
    );
  }
  const appDestination = "twenty-files-recovered",
    redisDestination = "twenty-queue-recovered";
  copyClaim(
    appClaim,
    appDestination,
    deployment.spec.template.spec.securityContext,
    values.securityContext,
    "test -s /recovered/.helmforge-identity.json; test -d /recovered/storage",
  );
  copyClaim(
    redisClaim,
    redisDestination,
    redis.spec.securityContext,
    redis.spec.containers[0].securityContext,
    "test -d /recovered/appendonlydir",
  );
  const recoveredRedis = structuredClone(redisSts.spec.template.spec);
  recoveredRedis.volumes = (recoveredRedis.volumes ?? []).filter(
    (volume) => volume.name !== redisDataMount.name,
  );
  recoveredRedis.volumes.push({
    name: redisDataMount.name,
    persistentVolumeClaim: { claimName: redisDestination },
  });
  const redisLabels = {
    ...redis.metadata.labels,
    "helmforge.dev/runtime-fixture": "true",
    "helmforge.dev/recovery": "twenty-queue",
  };
  apply({
    apiVersion: "apps/v1",
    kind: "Deployment",
    metadata: {
      name: redisDestination,
      labels: { "helmforge.dev/runtime-fixture": "true" },
    },
    spec: {
      replicas: 1,
      strategy: { type: "Recreate" },
      selector: { matchLabels: { "helmforge.dev/recovery": "twenty-queue" } },
      template: { metadata: { labels: redisLabels }, spec: recoveredRedis },
    },
  });
  k(["rollout", "status", "deployment/" + redisDestination, "--timeout=60s"]);
  const live = JSON.parse(
    k(["get", "deployment", deployment.metadata.name, "-o", "json"]),
  );
  const patch = [{ op: "replace", path: "/spec/replicas", value: 1 }];
  for (const group of ["initContainers", "containers"])
    for (const [index, container] of live.spec.template.spec[group].entries()) {
      const envIndex = container.env?.findIndex(
        (env) => env.name === "HF_DATABASE_NAME",
      );
      if (envIndex >= 0)
        patch.push({
          op: "replace",
          path:
            "/spec/template/spec/" +
            group +
            "/" +
            index +
            "/env/" +
            envIndex +
            "/value",
          value: "twenty_recovered",
        });
    }
  const volumeIndex = live.spec.template.spec.volumes.findIndex(
    (volume) => volume.name === "data",
  );
  patch.push({
    op: "replace",
    path:
      "/spec/template/spec/volumes/" +
      volumeIndex +
      "/persistentVolumeClaim/claimName",
    value: appDestination,
  });
  k([
    "patch",
    "deployment",
    deployment.metadata.name,
    "--type=json",
    "-p",
    JSON.stringify(patch),
  ]);
  k([
    "rollout",
    "status",
    "deployment/" + deployment.metadata.name,
    "--timeout=150s",
  ]);
  const completed = k([
    "exec",
    pod(),
    "-c",
    "worker",
    "--",
    "node",
    "--input-type=module",
    "-e",
    queueSetup +
      `
    try{const job=await queue.getJob(${JSON.stringify(queuedId)});assert.ok(job,'Pending native job must survive fresh Redis PVC recovery');assert.equal(await job.getState(),'delayed');await job.changeDelay(0);
    const deadline=Date.now()+45000;while(Date.now()<deadline&&(await job.getState())!=='completed')await new Promise(resolve=>setTimeout(resolve,500));assert.equal(await job.getState(),'completed');const done=await queue.getJob(job.id);assert.ok(done.processedOn>=${recoveryStart});assert.ok(done.finishedOn>=done.processedOn);
    const fs=require('node:fs');const walk=dir=>fs.readdirSync(dir,{withFileTypes:true}).flatMap(entry=>entry.isDirectory()?walk(dir+'/'+entry.name):[dir+'/'+entry.name]);
    const archives=walk('/app/data/storage').filter(path=>path.endsWith('twenty-client-sdk.zip')&&path.includes(done.data.workspaceId)&&path.includes(done.data.applicationUniversalIdentifier));assert.equal(archives.length,1);
    const archive=fs.readFileSync(archives[0]);assert.equal(archive.subarray(0,2).toString(),'PK');assert.ok(archive.length>1000);assert.ok(fs.statSync(archives[0]).mtimeMs>=done.processedOn,'Restored pending job must write a fresh native SDK archive');
    console.log('owned restored native SDK job completed and regenerated its archive');}
    finally{await queue.close();redis.disconnect();}`,
  ]);
  assert.match(completed, /owned restored native SDK job completed/);
  console.log(
    "PASS fresh database, files PVC and Redis PVC recovery including a retained pending native SDK job completed afterward",
  );
}
