# Backup & Restore Guide

## When to Use

Enable scheduled backups of your Minecraft server data to S3-compatible object storage. Essential for production servers where world data loss is unacceptable.

## What This Delivers

- CronJob-based backup on a configurable schedule
- RCON coordination: `save-all` and `save-off` before backup, `save-on` after
- Compressed tar archive of the `/data` directory
- Upload to any S3-compatible storage (AWS S3, MinIO, DigitalOcean Spaces, etc.)
- Separate Secret management for S3 credentials

## How It Works

```
CronJob triggers at schedule
  │
  ├─ Init: pre-backup
  │  └─ RCON → save-all flush → save-off
  │
  ├─ Init: archive
  │  └─ tar czf /data → minecraft-<timestamp>.tar.gz
  │
  ├─ Container: upload
  │  └─ mc (MinIO Client) → S3 bucket
  │
  └─ Container: post-backup
     └─ RCON → save-on
```

## Requirements

- `rcon.enabled: true` — required for save coordination
- `persistence.enabled: true` — backup reads from the PVC
- S3 endpoint, bucket, and credentials configured

## Example Configuration

### With Existing Secret (Recommended)

```bash
kubectl create secret generic minecraft-backup-s3 \
  --from-literal=access-key=AKIA... \
  --from-literal=secret-key=wJalr...
```

```yaml
backup:
  enabled: true
  schedule: "0 4 * * *"
  s3:
    endpoint: https://s3.amazonaws.com
    bucket: minecraft-backups
    prefix: production
    existingSecret: minecraft-backup-s3
```

### With Inline Credentials

```yaml
backup:
  enabled: true
  schedule: "0 4 * * *"
  s3:
    endpoint: https://minio.internal:9000
    bucket: minecraft-backups
    prefix: dev
    accessKey: minioadmin
    secretKey: minioadmin
```

## Backup Contents

The archive includes the entire `/data` directory minus excluded patterns:

| Included | Description |
|----------|-------------|
| `world/` | World save data |
| `plugins/` | Installed plugins |
| `mods/` | Installed mods |
| `config/` | Plugin and mod configs |
| `server.properties` | Server configuration |

| Excluded (default) | Description |
|---------------------|-------------|
| `*.jar` | Server and plugin JARs (re-downloaded on start) |
| `cache` | Temporary cache files |
| `logs` | Server logs |

Customize exclusions with `backup.excludes`.

## Restore Procedure

Restore is a manual operational task:

1. **Scale down the server**
   ```bash
   kubectl scale deployment <release>-minecraft --replicas=0
   ```

2. **Download the backup**
   ```bash
   mc cp backup/<bucket>/<prefix>/minecraft-<timestamp>.tar.gz ./backup.tar.gz
   ```

3. **Restore to the PVC** (via a temporary pod or `kubectl cp`)
   ```bash
   kubectl run restore --rm -it --restart=Never \
     --image=alpine:3 \
     --overrides='{"spec":{"containers":[{"name":"restore","image":"alpine:3","command":["sh"],"volumeMounts":[{"name":"data","mountPath":"/data"}]}],"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"<release>-minecraft"}}]}}' \
     -- sh -c "cd /data && rm -rf * && tar xzf /dev/stdin" < backup.tar.gz
   ```

4. **Scale up the server**
   ```bash
   kubectl scale deployment <release>-minecraft --replicas=1
   ```

5. **Verify** — connect to the server and confirm world data is intact.

## S3 Bucket Recommendations

- Enable **versioning** for accidental overwrite protection
- Enable **encryption** (SSE-S3 or SSE-KMS)
- Configure **lifecycle rules** to expire old backups automatically
- Consider **immutability** (Object Lock) for ransomware protection

## Common Risks

- **Save coordination failure** — if RCON cannot connect, the backup may capture an inconsistent world state
- **Storage limits** — large worlds generate large archives. Monitor bucket usage.
- **PVC access mode** — the backup CronJob mounts the PVC as read-only. With `ReadWriteOnce`, the backup pod must schedule on the same node as the server pod.

<!-- @AI-METADATA
type: chart-docs
title: Backup & Restore Guide
description: Guide for S3-based backup and restore procedures for Minecraft servers
keywords: minecraft, backup, restore, s3, minio, cronjob, rcon
purpose: Operational guidance for Minecraft server backup and restore
scope: Chart
relations:
  - charts/minecraft/README.md
  - charts/minecraft/values.yaml
path: charts/minecraft/docs/backup.md
version: 1.0
date: 2026-03-23
-->
