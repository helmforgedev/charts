// SPDX-License-Identifier: Apache-2.0
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";

export function verifyIsolation({
  context,
  namespace,
  release,
  k,
  deployment,
  pod,
  values,
}) {
  assert.equal(context, "k3d-helmforge-tests-wsl");
  const command = (args) =>
    execFileSync("kubectl", ["--context", context, "-n", namespace, ...args], {
      encoding: "utf8",
      timeout: 100000,
    });
  const waitForJob = (name, timeout) => {
    try {
      command([
        "wait",
        "--for=condition=complete",
        "job/" + name,
        "--timeout=" + timeout,
      ]);
    } catch (error) {
      // These owned Jobs mount no application credentials; preserve their failure
      // reason before cleanup removes the only diagnostic Pod.
      try {
        console.error(command(["logs", "job/" + name, "--tail=20"]));
      } catch {}
      throw error;
    }
  };
  const apply = (document) =>
    execFileSync(
      "kubectl",
      ["--context", context, "-n", namespace, "apply", "-f", "-"],
      { input: JSON.stringify(document), encoding: "utf8", timeout: 15000 },
    );
  const labels = {
    "app.kubernetes.io/name":
      deployment.spec.template.metadata.labels["app.kubernetes.io/name"],
    "app.kubernetes.io/instance": release,
    "helmforge.dev/isolation-fixture": "negative",
  };
  const admissionKey = deployment.spec.template.spec.volumes.find(
    (item) => item.name === "admission-key",
  ).secret.secretName;
  const runtime = deployment.spec.template.spec.volumes.find(
    (item) => item.name === "runtime",
  ).configMap.name;
  const image =
    values.admission.image.repository + ":" + values.admission.image.tag;
  const jobName = "rr-negative-admission",
    policyName = "rr-negative-admission";
  const code =
    "import {admit} from '/helmforge/admission.mjs';import fs from 'node:fs';try{await admit({key:fs.readFileSync('/admission-key/key'),helperHost:" +
    JSON.stringify(admissionKey) +
    ",timeout:4000});throw Error('UNEXPECTED_ADMISSION')}catch(error){if(!String(error).includes('Native port remains externally reachable'))throw error;console.log('PASS unenforced native-port isolation blocks enrollment')}";
  // This disposable Job has an explicit controller owner, so the application
  // ReplicaSet cannot adopt its Pod despite the shared policy selector labels.
  const job = {
    apiVersion: "batch/v1",
    kind: "Job",
    metadata: {
      name: jobName,
      labels: { "helmforge.dev/runtime-fixture": "true" },
    },
    spec: {
      backoffLimit: 0,
      activeDeadlineSeconds: 45,
      template: {
        metadata: { labels },
        spec: {
          restartPolicy: "Never",
          automountServiceAccountToken: false,
          securityContext: {
            runAsNonRoot: true,
            runAsUser: 1000,
            runAsGroup: 1000,
            fsGroup: 1000,
            seccompProfile: { type: "RuntimeDefault" },
          },
          containers: [
            {
              name: "check",
              image,
              command: ["node", "--input-type=module", "-e", code],
              securityContext: {
                allowPrivilegeEscalation: false,
                readOnlyRootFilesystem: true,
                capabilities: { drop: ["ALL"] },
              },
              resources: {
                requests: { cpu: "25m", memory: "32Mi" },
                limits: { cpu: "200m", memory: "128Mi" },
              },
              volumeMounts: [
                { name: "runtime", mountPath: "/helmforge", readOnly: true },
                {
                  name: "admission-key",
                  mountPath: "/admission-key",
                  readOnly: true,
                },
              ],
            },
          ],
          volumes: [
            {
              name: "runtime",
              configMap: {
                name: runtime,
                items: [{ key: "admission.mjs", path: "admission.mjs" }],
              },
            },
            {
              name: "admission-key",
              secret: { secretName: admissionKey, defaultMode: 288 },
            },
          ],
        },
      },
    },
  };
  const policy = {
    apiVersion: "networking.k8s.io/v1",
    kind: "NetworkPolicy",
    metadata: { name: policyName },
    spec: {
      podSelector: { matchLabels: labels },
      policyTypes: ["Ingress"],
      ingress: [
        {
          from: [
            {
              podSelector: {
                matchLabels: {
                  "app.kubernetes.io/name": "reactive-resume-admission",
                  "app.kubernetes.io/instance": release,
                },
              },
            },
          ],
          ports: [{ protocol: "TCP", port: 3010 }],
        },
      ],
    },
  };
  try {
    apply(policy);
    apply(job);
    waitForJob(jobName, "50s");
    assert.match(
      command(["logs", "job/" + jobName]),
      /PASS unenforced native-port isolation blocks enrollment/,
    );
  } finally {
    command([
      "delete",
      "job",
      jobName,
      "--ignore-not-found",
      "--wait=true",
      "--timeout=30s",
    ]);
    command(["delete", "networkpolicy", policyName, "--ignore-not-found"]);
  }
  const actual = JSON.parse(k(["get", "pod", pod(), "-o", "json"]));
  const addresses = actual.status.podIPs.map((item) => item.ip);
  const peerName = "rr-isolation-peer";
  const peerCode =
    "const net=require('node:net');(async()=>{for(const host of " +
    JSON.stringify(addresses) +
    "){const url='http://'+(host.includes(':')?'['+host+']':host)+':3000/api/health';console.log('Checking public address',host);let healthy=false,lastError;const deadline=Date.now()+15000;while(Date.now()<deadline){try{const r=await fetch(url,{signal:AbortSignal.timeout(3000)});if(r.ok){healthy=true;break}lastError=Error('Public status '+r.status)}catch(e){lastError=e}await new Promise(r=>setTimeout(r,500))}if(!healthy)throw Error('Public positive control failed for '+host+': '+lastError?.message+' '+(lastError?.cause?.code??''));await new Promise((resolve,reject)=>{const socket=net.connect({host,port:3010});socket.setTimeout(1500);socket.once('connect',()=>{socket.destroy();reject(Error('Native port exposed'))});socket.once('timeout',()=>{socket.destroy();resolve()});socket.once('error',error=>{socket.destroy();if(['ETIMEDOUT','ECONNREFUSED','EHOSTUNREACH'].includes(error.code))resolve();else reject(error)});});if(!(await fetch(url,{signal:AbortSignal.timeout(5000)})).ok)throw Error('Public control disappeared after the native denial');}console.log('PASS public health reachable and native listener denied for every Pod address family')})().catch(error=>{console.error(error.message);process.exitCode=1});";
  const peer = {
    apiVersion: "batch/v1",
    kind: "Job",
    metadata: {
      name: peerName,
      labels: { "helmforge.dev/runtime-fixture": "true" },
    },
    spec: {
      backoffLimit: 0,
      activeDeadlineSeconds: 60,
      template: {
        metadata: { labels: { app: peerName } },
        spec: {
          restartPolicy: "Never",
          automountServiceAccountToken: false,
          securityContext: {
            runAsNonRoot: true,
            runAsUser: 1000,
            runAsGroup: 1000,
            seccompProfile: { type: "RuntimeDefault" },
          },
          containers: [
            {
              name: "check",
              image,
              command: ["node", "-e", peerCode],
              securityContext: {
                allowPrivilegeEscalation: false,
                readOnlyRootFilesystem: true,
                capabilities: { drop: ["ALL"] },
              },
              resources: {
                requests: { cpu: "25m", memory: "32Mi" },
                limits: { cpu: "200m", memory: "128Mi" },
              },
            },
          ],
        },
      },
    },
  };
  try {
    apply(peer);
    waitForJob(peerName, "65s");
    assert.match(
      command(["logs", "job/" + peerName]),
      /PASS public health reachable and native listener denied/,
    );
  } finally {
    command([
      "delete",
      "job",
      peerName,
      "--ignore-not-found",
      "--wait=true",
      "--timeout=30s",
    ]);
  }
  console.log(
    "PASS actual CNI rejection with deliberately exposed enrollment port and protected native application listener",
  );
}
