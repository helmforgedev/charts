# Automated Backup

The openHAB chart includes an optional automated backup system that uses a Kubernetes CronJob to create compressed archives of your openHAB data directories and upload them to any S3-compatible object storage.

## How It Works

The backup runs as a two-stage Kubernetes Job:

1. **Backup initContainer** (`alpine`) — runs `backup.sh`:
   - Creates a `.tar.gz` archive of selected directories into a shared `/tmp` volume
   - Excludes `userdata/logs`, `userdata/tmp`, and `userdata/cache` (ephemeral, not needed for restore)

2. **Upload container** (`helmforge/mc`) — runs `upload.sh`:
   - Picks up the archive from `/tmp`
   - Configures the MinIO client with your S3 credentials
   - Uploads the archive to `s3://<bucket>/<prefix>/<filename>`

Both containers run with the same UID/GID (9001) as openHAB, ensuring read access to the PVCs.

## Enabling Backup

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"  # Daily at 03:00 UTC

  s3:
    endpoint: "https://minio.example.com"
    bucket: "openhab-backups"
    prefix: "prod"
    accessKey: "AKIAEXAMPLE"
    secretKey: "supersecretkey"
```

## What Gets Backed Up

| Directory            | Default | Description                               |
|----------------------|---------|-------------------------------------------|
| `/openhab/userdata`  | ✅      | JSONDB, persistence data, rules state     |
| `/openhab/conf`      | ✅      | Items, things, sitemaps, rules files      |

**Always excluded from `userdata`:**

- `userdata/logs` — log files (not needed for restore)
- `userdata/tmp` — temporary files
- `userdata/cache` — OSGi bundle cache (rebuilt automatically on startup)

### Backing Up Only Userdata

If you manage `/openhab/conf` via ConfigMaps (GitOps), you can skip it:

```yaml
backup:
  enabled: true
  include:
    userdata: true
    conf: false
```

## Using an Existing Secret

To avoid storing S3 credentials in your `values.yaml`, create a Secret manually and reference it:

```bash
kubectl create secret generic my-s3-credentials \
  --from-literal=access-key=AKIAEXAMPLE \
  --from-literal=secret-key=supersecretkey \
  -n openhab
```

```yaml
backup:
  enabled: true
  s3:
    endpoint: "https://minio.example.com"
    bucket: "openhab-backups"
    prefix: "prod"
    existingSecret: "my-s3-credentials"
```

## S3 Compatibility

The uploader uses the MinIO client (`mc`), which is compatible with any S3-compatible service:

| Provider        | Endpoint format                         |
|-----------------|-----------------------------------------|
| MinIO           | `https://minio.example.com`             |
| AWS S3          | `https://s3.amazonaws.com`              |
| Cloudflare R2   | `https://<account>.r2.cloudflarestorage.com` |
| Backblaze B2    | `https://s3.<region>.backblazeb2.com`   |
| DigitalOcean Spaces | `https://<region>.digitaloceanspaces.com` |

## Archive Naming

Archives follow this pattern:

```
<archivePrefix>-backup-<YYYY-MM-DD-HHmmss>.tar.gz
```

Default example: `openhab-backup-2025-01-15-030000.tar.gz`

You can change the prefix:

```yaml
backup:
  archivePrefix: myhome
```

## Resource Limits

By default, backup containers have no resource limits set. For production use:

```yaml
backup:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 256Mi
```

## Suspending Backups

To temporarily pause backups without deleting the CronJob:

```yaml
backup:
  enabled: true
  suspend: true
```

## Viewing Backup History

```bash
# List recent backup jobs
kubectl get jobs -n openhab -l app.kubernetes.io/component=backup

# View logs from the latest backup run
kubectl logs -n openhab -l app.kubernetes.io/component=backup --tail=50

# Check job status
kubectl describe cronjob openhab-backup -n openhab
```

## Restore Process

To restore from a backup:

1. Download the archive from your S3 bucket
2. Scale down openHAB to 0 replicas (required — openHAB holds locks on its data):

```bash
kubectl scale statefulset openhab -n openhab --replicas=0
```

3. Extract the archive into the PVC via a temporary pod:

```bash
kubectl run restore --rm -it --image=alpine --restart=Never \
  --overrides='{"spec":{"volumes":[{"name":"userdata","persistentVolumeClaim":{"claimName":"openhab-userdata"}}],"containers":[{"name":"restore","image":"alpine","command":["sh"],"stdin":true,"tty":true,"volumeMounts":[{"name":"userdata","mountPath":"/openhab/userdata"}]}]}}' \
  -- sh

# Inside the pod:
tar -xzf /path/to/openhab-backup-<timestamp>.tar.gz -C /
exit
```

4. Scale openHAB back to 1:

```bash
kubectl scale statefulset openhab -n openhab --replicas=1
```
