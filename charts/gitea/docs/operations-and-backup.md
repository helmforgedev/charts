<!-- SPDX-License-Identifier: Apache-2.0 -->

# Operations and Backup

This page covers day-two operations for the HelmForge Gitea chart: readiness,
local access, admin bootstrap, SSH exposure, backups, and common troubleshooting.

## Readiness

Wait for the Gitea pod:

```bash
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=gitea \
  -n gitea \
  --timeout=300s
```

Check recent logs:

```bash
kubectl logs -l app.kubernetes.io/name=gitea \
  -n gitea \
  --all-containers \
  --tail=100
```

## Local HTTP Access

For a release named `gitea` in namespace `gitea`:

```bash
kubectl port-forward -n gitea svc/gitea-http 3000:3000
```

Open `http://localhost:3000/` and complete the initial setup wizard, or enable
the admin bootstrap Job with `admin.username`.

## SSH Access

Local SSH port-forward:

```bash
kubectl port-forward -n gitea svc/gitea-ssh 2222:2222
```

External SSH through NodePort:

```yaml
service:
  ssh:
    enabled: true
    type: NodePort
    nodePort: 30022
gitea:
  sshDomain: git.example.com
  sshPort: 2222
```

Clone URL:

```bash
git clone ssh://git@git.example.com:30022/<user>/<repo>.git
```

## Admin Bootstrap

When `admin.username` is set, the chart renders a post-install hook Job named
`<release>-gitea-admin-create`. The Job waits for the HTTP health endpoint and
then runs `gitea admin user create`.

Inspect the Job:

```bash
kubectl get job -n gitea -l app.kubernetes.io/component=admin-create
kubectl logs -n gitea -l app.kubernetes.io/component=admin-create --tail=100
```

## S3-Compatible Backups

Enable backups with an S3-compatible endpoint and credentials:

```yaml
backup:
  enabled: true
  schedule: "0 2 * * *"
  archivePrefix: gitea-prod
  s3:
    endpoint: https://s3.example.com
    bucket: platform-backups
    prefix: gitea
    existingSecret: gitea-s3-credentials
```

The S3 secret keys default to:

| Key | Purpose |
| --- | --- |
| `access-key` | S3 access key. |
| `secret-key` | S3 secret key. |

Trigger a manual backup:

```bash
kubectl create job -n gitea \
  --from=cronjob/gitea-backup \
  gitea-backup-manual
```

Check backup logs:

```bash
kubectl logs -n gitea \
  -l app.kubernetes.io/component=backup \
  --tail=100
```

## Production Checklist

- Use PostgreSQL or MySQL for multi-user production installations.
- Set `gitea.rootUrl` and `gitea.sshDomain` to externally reachable hostnames.
- Store admin, database, and S3 credentials in existing Kubernetes Secrets or
  External Secrets.
- Keep `volumePermissions.enabled=false` unless your storage class requires root
  ownership repair.
- Configure resource requests and limits for the Gitea pod, database subchart,
  and backup CronJob.
- Test backup restore procedures before relying on scheduled backups.

## Troubleshooting

Describe all rendered resources for the release:

```bash
kubectl get all,pvc,secret -n gitea \
  -l app.kubernetes.io/instance=gitea
```

Inspect events:

```bash
kubectl get events -n gitea --sort-by=.lastTimestamp
```

For database modes, check the `wait-for-db` init container logs when the Gitea pod
does not start:

```bash
kubectl logs -n gitea deploy/gitea -c wait-for-db
```
