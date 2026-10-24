<!-- SPDX-License-Identifier: Apache-2.0 -->
# Apache Superset operations

## Installation checks

Watch the initialization Job before the Deployments. Its name includes the Helm
release revision so every upgrade has auditable migration status.

```bash
kubectl get job,pod -n <namespace> \
  -l app.kubernetes.io/instance=<release>
kubectl logs -n <namespace> \
  job/<release>-superset-init-<revision>
kubectl wait -n <namespace> --for=condition=available \
  deployment/<release>-superset-web --timeout=10m
```

The web `/health` endpoint proves that Gunicorn is serving requests. It does not
prove that external data sources, Celery tasks, reports, or backups work.

```bash
kubectl port-forward -n <namespace> \
  service/<release>-superset 8088:<service-port>
curl --fail http://127.0.0.1:8088/health
```

## Upgrade procedure

1. Back up PostgreSQL and record the Superset image and chart versions.
2. Preserve the current `SECRET_KEY` and administrator Secret.
3. Read the upstream updating notes for every crossed major version.
4. Render the new values and review datastore, image, and security changes.
5. Upgrade during a migration window and follow the revisioned init Job logs.
6. Verify `/health`, login, representative dashboards, SQL Lab, Celery tasks,
   alerts, reports, and backup status.

Do not roll back application pods across an irreversible database migration.
Restore the database backup and matching `SECRET_KEY` when the upstream
migration guidance requires a data rollback.

## Scaling

Scale `web.replicaCount` for HTTP traffic and `worker.replicaCount` plus
`worker.concurrency` for asynchronous work. Size Gunicorn worker count against
pod CPU and memory. Keep Beat at one replica. The bundled standalone PostgreSQL
and Redis charts remain single points of failure even when the application tier
is scaled. If `init.enabled=false`, keep one web replica for as long as that
fallback is active; enable the managed init Job before scaling web pods.

## Backup and restore

The optional CronJob writes the complete compressed `pg_dump` archive to
`/backup/out` on an `emptyDir` before uploading it to S3-compatible storage.
The archive must fit in available node ephemeral storage; size and monitor the
backup nodes accordingly. Alert on failed Jobs and object age. Redis is not
included because PostgreSQL is the metadata source of truth.

Before declaring backups usable, restore one into an isolated PostgreSQL
instance, deploy the same Superset version with the original `SECRET_KEY`, and
verify users, connections, dashboards, and encrypted credentials. The chart
does not automate restore because overwriting production metadata requires an
explicit operator decision.

## Troubleshooting

If a wait container does not finish, inspect the init Job and confirm the
ServiceAccount can `get`, `list`, and `watch` Jobs in the namespace. If an init
container waits for a datastore, check the mode/subchart pairing, dependency
naming overrides, Service endpoints, Secret key names, TLS settings, and egress
policy.

```bash
kubectl describe pod -n <namespace> <pod>
kubectl get service,endpointslice -n <namespace>
kubectl get events -n <namespace> --sort-by=.lastTimestamp
kubectl logs -n <namespace> deployment/<release>-superset-web --tail=200
kubectl logs -n <namespace> deployment/<release>-superset-worker --tail=200
```

When runtime package installation fails, build a derived image with all drivers
instead of retrying an unpinned network-dependent startup.
