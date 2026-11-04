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
Restore into an empty namespace and recreate Secrets with the same key names.
Immediately scale the Discourse Deployment to zero before restoring either data
domain:

```bash
kubectl scale deployment -n NAMESPACE \
  -l app.kubernetes.io/instance=RELEASE,app.kubernetes.io/name=discourse \
  --replicas=0
```

Restore PostgreSQL and `/shared` completely, verify both restorations, and only
then scale the Deployment back to one. Do not run `helm upgrade` during the
restore because Helm would reapply the chart's single replica.

Never treat a Helm release, Redis snapshot, PVC manifest, or database dump alone
as a complete backup. The chart intentionally does not automate retention,
immutability, encryption, or restore orchestration.
