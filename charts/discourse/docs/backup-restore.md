<!-- SPDX-License-Identifier: Apache-2.0 -->

# Backup and Restore

A recoverable Discourse backup has two coordinated domains:

1. PostgreSQL, including schema, extensions, and forum data.
2. `/shared`, including uploads, backups, logs, and runtime files.

Redis is disposable cache/coordination state and is normally rebuilt. Stop writes
or use storage/database snapshots with a shared consistency point. Encrypt backup
artifacts, retain them outside the cluster, and test restoration regularly.

For bundled PostgreSQL, use `pg_dump`/`pg_restore` through the PostgreSQL pod or
your platform backup controller. Snapshot or copy the `/shared` PVC separately.
Restore into an empty namespace and restore the original Secret values, not only
their key names. In particular, preserve the application `secret-key-base` and
the bundled PostgreSQL credentials. Alternatively, configure
`discourse.existingSecret` and `postgresql.auth.existingSecret` with Secrets that
contain those exact backed-up values before starting Discourse.

Resolve the single Deployment owned by the release and scale it to zero before
restoring either data domain. The explicit count check prevents restoration from
continuing if the selector finds no Deployment or an ambiguous set:

```bash
set -euo pipefail
DEPLOYMENT=$(kubectl get deployment -n NAMESPACE \
  -l app.kubernetes.io/instance=RELEASE -o name)
test "$(printf '%s\n' "$DEPLOYMENT" | sed '/^$/d' | wc -l)" -eq 1
kubectl scale "$DEPLOYMENT" -n NAMESPACE --replicas=0
```

Restore PostgreSQL and `/shared` completely, verify both restorations, and only
then scale the Deployment back to one:

```bash
kubectl scale "$DEPLOYMENT" -n NAMESPACE --replicas=1
```

Do not run `helm upgrade` during the restore because Helm would reapply the
chart's single replica.

Never treat a Helm release, Redis snapshot, PVC manifest, or database dump alone
as a complete backup. The chart intentionally does not automate retention,
immutability, encryption, or restore orchestration.
