// SPDX-License-Identifier: Apache-2.0
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";

export function restoreSmoke({
  context,
  namespace,
  release,
  k,
  values,
  deployment,
  pod,
}) {
  assert.equal(context, "k3d-helmforge-tests-wsl");
  assert.equal(namespace, "hf-validate-reactive-resume");
  assert.equal(deployment.metadata.name, "reactive-resume-restore");
  assert.equal(values.postgresql.enabled, true);
  assert.equal(values.storage.driver, "local");
  const oldPod = pod();
  const source = deployment.spec.template.spec.volumes.find(
    (v) => v.name === "data",
  ).persistentVolumeClaim.claimName;
  k(["scale", "deployment/" + deployment.metadata.name, "--replicas=0"]);
  k(["wait", "--for=delete", "pod/" + oldPod, "--timeout=60s"]);
  const databasePod = JSON.parse(
    k([
      "get",
      "pods",
      "-l",
      "app.kubernetes.io/name=postgresql,app.kubernetes.io/instance=" + release,
      "-o",
      "json",
    ]),
  ).items[0];
  assert.ok(databasePod);
  const backup = `
    set -euo pipefail
    umask 077
    export PGPASSWORD="$APP_PASSWORD"
    pg_dump -h 127.0.0.1 -U "$APP_USERNAME" -d "$APP_DATABASE" -Fc -f /tmp/reactive-resume.dump
    export PGPASSWORD="$POSTGRES_PASSWORD"
    createdb -h 127.0.0.1 -U "$POSTGRES_USER" --owner="$APP_USERNAME" reactive_resume_recovered
    pg_restore -h 127.0.0.1 -U "$POSTGRES_USER" -d reactive_resume_recovered --exit-on-error --no-owner --no-privileges --role="$APP_USERNAME" /tmp/reactive-resume.dump
    rm /tmp/reactive-resume.dump
    echo owned-reactive-resume-database-recovered
  `;
  assert.match(
    k([
      "exec",
      databasePod.metadata.name,
      "-c",
      databasePod.spec.containers[0].name,
      "--",
      "bash",
      "-ceu",
      backup,
    ]),
    /owned-reactive-resume-database-recovered/,
  );
  const original = JSON.parse(k(["get", "pvc", source, "-o", "json"]));
  const name = "reactive-resume-recovered";
  const apply = (document) =>
    execFileSync(
      "kubectl",
      ["--context", context, "-n", namespace, "apply", "-f", "-"],
      { input: JSON.stringify(document), encoding: "utf8", timeout: 15000 },
    );
  apply({
    apiVersion: "v1",
    kind: "PersistentVolumeClaim",
    metadata: { name },
    spec: {
      accessModes: original.spec.accessModes,
      storageClassName: original.spec.storageClassName,
      resources: original.spec.resources,
    },
  });
  const copyName = "reactive-resume-recovery";
  const archive =
    "set -o pipefail; umask 077; cd /source; find . -mindepth 1 -maxdepth 1 -print0 | tar --null -T - -czf /tmp/owned-resume.tar.gz; tar --no-same-owner --no-overwrite-dir -xzf /tmp/owned-resume.tar.gz -C /recovered; test -s /recovered/.helmforge-identity.json; test -d /recovered/uploads; echo owned-reactive-resume-volume-recovered";
  apply({
    apiVersion: "v1",
    kind: "Pod",
    metadata: {
      name: copyName,
      labels: { "helmforge.dev/runtime-fixture": "true" },
    },
    spec: {
      restartPolicy: "Never",
      automountServiceAccountToken: false,
      securityContext: deployment.spec.template.spec.securityContext,
      containers: [
        {
          name: "restore",
          image: databasePod.spec.containers[0].image,
          command: ["bash", "-ceu", archive],
          securityContext: values.securityContext,
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
  const copyDeadline = Date.now() + 60000;
  let copyPhase;
  do {
    copyPhase = JSON.parse(k(["get", "pod", copyName, "-o", "json"])).status
      .phase;
    if (copyPhase === "Succeeded" || copyPhase === "Failed") break;
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 500);
  } while (Date.now() < copyDeadline);
  const copyLogs = k(["logs", copyName]);
  assert.equal(
    copyPhase,
    "Succeeded",
    "Owned recovery helper failed: " + copyLogs,
  );
  assert.match(copyLogs, /owned-reactive-resume-volume-recovered/);
  k(["delete", "pod/" + copyName, "--wait=true", "--timeout=30s"]);
  const live = JSON.parse(
    k(["get", "deployment", deployment.metadata.name, "-o", "json"]),
  );
  const patch = [{ op: "replace", path: "/spec/replicas", value: 1 }];
  for (const group of ["initContainers", "containers"]) {
    for (const [index, container] of live.spec.template.spec[group].entries()) {
      const envIndex = container.env?.findIndex(
        (e) => e.name === "HF_DATABASE_NAME",
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
          value: "reactive_resume_recovered",
        });
    }
  }
  const volumeIndex = live.spec.template.spec.volumes.findIndex(
    (v) => v.name === "data",
  );
  patch.push({
    op: "replace",
    path:
      "/spec/template/spec/volumes/" +
      volumeIndex +
      "/persistentVolumeClaim/claimName",
    value: name,
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
    "--timeout=120s",
  ]);
  const recoveredClaim = JSON.parse(k(["get", "pvc", name, "-o", "json"]));
  assert.notEqual(recoveredClaim.metadata.uid, original.metadata.uid);
  console.log(
    "PASS quiesced database and upload archive recovered into a new database and PVC with retained identity marker",
  );
}
