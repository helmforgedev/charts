// SPDX-License-Identifier: Apache-2.0
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";

export async function recoverDatabase({ k, context, namespace, release, chartPath, deployment }) {
  assert.equal(
    deployment.metadata.name,
    "ryot-restore",
    "Only the dedicated disposable recovery profile may create a database",
  );
  const databasePod = JSON.parse(
    k(["get", "pods", "-l", `app.kubernetes.io/instance=${release},app.kubernetes.io/name=postgresql`, "-o", "json"]),
  ).items[0];
  assert.ok(databasePod);
  k(["scale", "deployment/" + deployment.metadata.name, "--replicas=0"]);
  k([
    "wait",
    "--for=delete",
    "pod",
    "-l",
    `app.kubernetes.io/instance=${release},app.kubernetes.io/name=ryot`,
    "--timeout=60s",
  ]);
  const script = `set -euo pipefail
umask 077
export PGPASSWORD="$APP_PASSWORD"
pg_dump -h 127.0.0.1 -U "$APP_USERNAME" -d "$APP_DATABASE" -Fc -f /tmp/ryot-recovery.dump
export PGPASSWORD="$POSTGRES_PASSWORD"
psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$POSTGRES_USER" -d postgres --set=owner="$APP_USERNAME" <<'SQL'
SELECT format('CREATE DATABASE ryot_recovered OWNER %I', :'owner') \\gexec
SQL
pg_restore -h 127.0.0.1 -U "$POSTGRES_USER" -d ryot_recovered --exit-on-error --no-owner --role="$APP_USERNAME" /tmp/ryot-recovery.dump
rm /tmp/ryot-recovery.dump
echo 'Native logical backup restored into a separate empty database'
`;
  k(["exec", databasePod.metadata.name, "-c", databasePod.spec.containers[0].name, "--", "bash", "-ceu", script]);
  execFileSync(
    "helm",
    [
      "upgrade",
      release,
      chartPath,
      "--kube-context",
      context,
      "-n",
      namespace,
      "--reuse-values",
      "--set",
      "postgresql.auth.database=ryot_recovered",
      "--wait",
      "--timeout",
      "120s",
    ],
    { encoding: "utf8", timeout: 135000 },
  );
  console.log("PASS native pg_dump/pg_restore into a separate empty database; original database preserved");
}
