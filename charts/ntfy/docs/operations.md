<!-- SPDX-License-Identifier: Apache-2.0 -->

# ntfy Operations

## Deployment Verification

```bash
kubectl wait --for=condition=Ready pod \
  -n <namespace> \
  -l app.kubernetes.io/instance=<release>,app.kubernetes.io/component=server \
  --timeout=300s
kubectl get deploy,svc,pod,pvc -n <namespace> \
  -l app.kubernetes.io/instance=<release>
kubectl logs -n <namespace> deploy/<release>-ntfy --tail=200
```

Verify the health endpoint through the Service:

```bash
kubectl port-forward -n <namespace> svc/<release>-ntfy 2586:80
curl --fail http://127.0.0.1:2586/v1/health
```

## Upgrades

Before an application or chart upgrade:

1. Review the upstream ntfy release notes and database migration notes.
2. Back up the data PVC and any external PostgreSQL database.
3. Confirm that the target image supports the configured OIDC, SMTP, and
   database options.
4. Upgrade in a non-production namespace using restored production data.
5. Verify health, publish and subscribe flows, attachments, authentication,
   and external integrations before production rollout.

After a Secret rotation, restart the Deployment because database, OIDC, and
SMTP credentials are injected as environment variables:

```bash
kubectl rollout restart -n <namespace> deploy/<release>-ntfy
kubectl rollout status -n <namespace> deploy/<release>-ntfy --timeout=300s
```

## S3 Backup

The optional CronJob archives the contents of `/var/cache/ntfy` from the PVC
and uploads one compressed archive to S3-compatible storage. It covers SQLite
databases, attachments, and other files on that volume. It does not dump a
PostgreSQL database.

```bash
kubectl get cronjob,jobs -n <namespace> \
  -l app.kubernetes.io/instance=<release>,app.kubernetes.io/component=backup
kubectl create job -n <namespace> \
  --from=cronjob/<release>-ntfy-backup ntfy-backup-manual
kubectl logs -n <namespace> job/ntfy-backup-manual --all-containers
```

## Restore

Test restores regularly in an isolated namespace. A safe restore sequence is:

1. Scale the ntfy Deployment to zero.
2. Download and verify the intended archive from object storage.
3. Mount the target PVC in a temporary maintenance pod.
4. Remove only the old ntfy data from `/var/cache/ntfy`, then extract the
   archive into that directory while preserving ownership for UID/GID 1000.
5. Restore PostgreSQL separately when that backend is enabled.
6. Remove the maintenance pod, scale ntfy to one, and verify health,
   authentication, attachments, and publish/subscribe behavior.

Do not restore an untrusted archive. Keep the application stopped while files
are replaced so SQLite and attachment state remain consistent.

## Troubleshooting

Inspect scheduling, mounts, probes, and recent cluster events:

```bash
kubectl describe pod -n <namespace> \
  -l app.kubernetes.io/instance=<release>,app.kubernetes.io/component=server
kubectl get events -n <namespace> --sort-by=.lastTimestamp
helm get manifest <release> -n <namespace>
```

Common checks:

- Permission errors: verify the PVC supports UID/GID 1000 and the pod security
  context was not overridden incompatibly.
- Probe failures after a port change: verify `containerPorts.http`; do not
  override `listen-http` through extra configuration.
- Database failures: verify the Secret name and key, network reachability, and
  TLS requirements of the PostgreSQL service.
- OIDC or SMTP failures: verify the issuer or sender address, Secret keys,
  cluster clock, DNS, and NetworkPolicy egress.
- Missing attachments after restart: confirm `persistence.enabled=true` and
  that the expected PVC is mounted.
