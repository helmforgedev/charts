<!-- SPDX-License-Identifier: Apache-2.0 -->
# Appwrite operations guide

## Readiness and validation

Wait for every component and verify that all three Services have endpoints:

```bash
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=<release> \
  -n <namespace> --timeout=600s
kubectl get endpoints -n <namespace> \
  <release>-appwrite-api \
  <release>-appwrite-console \
  <release>-appwrite-realtime
```

Check the API from inside its container with
`curl -fsS http://127.0.0.1:<api.containerPort>/v1/health/version`.

## Upgrades

Back up MariaDB, the application Secret, and all shared PVCs. Read the Appwrite
release notes for every skipped version. Upgrade the chart with retained values,
then run `migrate` in the API Deployment while traffic is paused. Verify the
health endpoint, an existing account and project, worker logs, and persisted
files before restoring traffic.

Never treat `helm rollback` as a database rollback. Restore the matching
database, Secret, PVC snapshots, and old images together when a migration must
be reversed.

## Backup and restore boundary

The optional CronJob runs `mariadb-dump` and uploads the archive to an
S3-compatible bucket. It does not capture Appwrite uploads, functions, builds,
sites, certificates, or external ClickHouse. Use CSI snapshots or a volume-aware
backup tool for those PVCs. Schedule and test a complete restore that combines
all artifacts from one recovery point.

## Troubleshooting

Use component labels to isolate logs:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/component=api \
  --all-containers --tail=100
kubectl logs -n <namespace> -l app.kubernetes.io/component=realtime \
  --all-containers --tail=100
kubectl get events -n <namespace> --sort-by=.lastTimestamp
kubectl get pvc,networkpolicy -n <namespace>
```

For Console failures, verify that `/`, `/v1`, and `/v1/realtime` use the same
host and route to Console, API, and realtime respectively. For worker failures,
check MariaDB and Redis connectivity, credentials, queue state, and shared PVC
mounts before restarting workloads.
