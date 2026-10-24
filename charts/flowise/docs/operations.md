<!-- SPDX-License-Identifier: Apache-2.0 -->
# Flowise operations

## Health and rollout checks

The main Deployment uses `/api/v1/ping` for startup, readiness, and liveness.
After upgrades, wait for all Deployments and inspect worker logs separately:

```bash
kubectl rollout status deployment -l app.kubernetes.io/instance=flowise --timeout=300s
kubectl get pods -l app.kubernetes.io/instance=flowise
kubectl logs -l app.kubernetes.io/instance=flowise,app.kubernetes.io/component=main --tail=100
kubectl logs -l app.kubernetes.io/instance=flowise,app.kubernetes.io/component=worker --tail=100
```

## Scaling

SQLite and local blob storage support one main replica. Queue mode can scale
`flowise.replicaCount` and `queue.worker.replicaCount` independently after
PostgreSQL, Redis, and S3 have sufficient capacity. Increase worker concurrency
only after measuring model-provider limits and memory use.

## Upgrades

Back up the standalone PVC or PostgreSQL before upgrading. The change from
`/root/.flowise` to `/home/node/.flowise` does not move files inside the PVC:
both paths mount the PVC root. Custom absolute paths must be updated manually.
After rollout, verify login, one representative chatflow, S3 reads and writes,
and queue processing.

## Troubleshooting

An init container waiting indefinitely normally indicates DNS, NetworkPolicy,
or credentials for PostgreSQL or Redis. A pod failing with a permission error
usually means an existing volume is not writable by UID/GID 1000 or the storage
driver does not apply `fsGroup`. Application errors should be compared with the
official Flowise environment variable reference before adding `extraEnv`.

Inspect events and rendered values:

```bash
kubectl get events --sort-by=.lastTimestamp
helm get values flowise --all
helm get manifest flowise
```
