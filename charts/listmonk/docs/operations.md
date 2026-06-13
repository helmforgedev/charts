<!-- SPDX-License-Identifier: Apache-2.0 -->

# Listmonk Operations

## Preflight

Render the target values and run the chart gate:

```bash
helm template listmonk charts/listmonk -f values.yaml
make validate-chart CHART=listmonk
```

Verify the pinned images:

```bash
make image-verify IMAGE=docker.io/listmonk/listmonk:v6.1.0
make image-verify IMAGE=docker.io/library/postgres:17-alpine
make image-verify IMAGE=docker.io/helmforge/mc:1.0.0
```

## Installation

Bundled PostgreSQL:

```bash
helm install listmonk helmforge/listmonk
kubectl port-forward svc/listmonk 9000:80
```

Open `http://localhost:9000`, create the first Super Admin account, then
configure SMTP in Settings > SMTP.

## Production Checklist

- Decide between bundled PostgreSQL and an external managed PostgreSQL service.
- Use existing Secrets for external database and backup credentials.
- Set resource requests and limits for Listmonk, PostgreSQL, and backup jobs.
- Set ingress TLS or provide an equivalent edge proxy.
- Back up both PostgreSQL and the uploads PVC.
- Configure DNS records required for email deliverability outside the chart.

## Health Checks

Check rollout and init container status:

```bash
kubectl rollout status deploy/listmonk
kubectl get pods -l app.kubernetes.io/name=listmonk
kubectl logs deploy/listmonk -c listmonk --tail=100
```

If startup stalls, inspect init containers:

```bash
kubectl logs deploy/listmonk -c wait-for-postgresql --tail=100
kubectl logs deploy/listmonk -c db-init --tail=100
```

## Backup and Restore

Enable database backups with an existing S3 credential Secret:

```yaml
backup:
  enabled: true
  s3:
    endpoint: https://s3.amazonaws.com
    bucket: listmonk-backups
    existingSecret: listmonk-s3-credentials
```

Restore testing should verify:

- PostgreSQL database dump imports successfully;
- the Super Admin account can log in;
- lists, subscribers, and campaigns are present;
- uploaded media still exists after restoring the uploads PVC.

## Common Issues

### Init container waits forever

The database host or port is unreachable. Check the selected database mode:

```bash
helm get values listmonk
kubectl logs deploy/listmonk -c wait-for-postgresql --tail=100
```

### Database migration fails

Inspect the `db-init` logs and verify database privileges:

```bash
kubectl logs deploy/listmonk -c db-init --tail=200
```

For external PostgreSQL, ensure the user can create required objects in the
configured database.

### Uploaded images disappear

Check whether `storage.enabled=false`, a different existing PVC was configured,
or the uploads PVC was deleted:

```bash
kubectl get pvc
kubectl describe deploy/listmonk
```

### Backups do not run

Check the CronJob and last Job:

```bash
kubectl get cronjob listmonk-backup
kubectl describe cronjob listmonk-backup
kubectl logs job/<job-name> --all-containers
```

Backups require database credentials plus S3 endpoint, bucket, and credentials.
