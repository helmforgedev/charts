# Backup and Restore

## Overview

The chart provides an automated S3 snapshot CronJob that registers an Elasticsearch snapshot repository and creates scheduled snapshots with configurable retention.

## Enable backups

```yaml
backup:
  enabled: true
  schedule: "0 2 * * *"   # daily at 2am
  retention:
    days: 30               # delete snapshots older than 30 days

  s3:
    bucket: my-es-backups
    region: us-east-1
    existingSecret: es-s3-credentials   # keys: access-key, secret-key
```

## Credentials secret

```bash
kubectl create secret generic es-s3-credentials \
  --from-literal=access-key=AKIAIOSFODNN7EXAMPLE \
  --from-literal=secret-key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY \
  -n <namespace>
```

## MinIO / S3-compatible storage

```yaml
backup:
  s3:
    endpoint: http://minio.minio-ns.svc.cluster.local:9000
    bucket: elasticsearch-backups
    region: us-east-1
    existingSecret: es-s3-credentials
```

## Manual snapshot

Trigger a one-off snapshot without waiting for the scheduled CronJob:

```bash
kubectl create job \
  --from=cronjob/<release>-elasticsearch-backup \
  manual-$(date +%s) \
  -n <namespace>
```

## List all snapshots

```bash
kubectl port-forward svc/<release>-elasticsearch 9200 -n <namespace>
curl http://localhost:9200/_snapshot/helmforge-s3/_all?pretty
```

## Restore a snapshot

```bash
# Close any conflicting open indices first
curl -X POST "localhost:9200/<index-name>/_close"

# Restore
curl -X POST "localhost:9200/_snapshot/helmforge-s3/<snapshot-name>/_restore?pretty" \
  -H 'Content-Type: application/json' \
  -d '{
    "indices": "*",
    "ignore_unavailable": true,
    "include_global_state": false
  }'

# Monitor restore
curl "localhost:9200/_recovery?active_only=true&pretty"
```

## Restore to a new cluster

1. Install the chart in a new namespace with `backup.enabled=true` and the same S3 credentials
2. Wait for the cluster to form and the backup CronJob to register the repository
3. List snapshots and restore as above

## Retention

Snapshots older than `backup.retention.days` are automatically deleted after each successful snapshot run. The retention script uses the Elasticsearch `_snapshot` API to list and delete by creation date.

## Common risks

- deleting the S3 bucket or prefix before restoring — always verify bucket contents before cleanup
- restoring to a cluster with a different major version — cross-major-version restores are not supported by Elasticsearch
- not testing the restore procedure before you need it

<!-- @AI-METADATA
type: chart-docs
title: Elasticsearch - Backup and Restore
description: S3 snapshot backup and restore guidance

keywords: elasticsearch, backup, restore, s3, snapshots

purpose: Backup and restore guidance for the Elasticsearch Helm chart
scope: Chart Operations

relations:
  - charts/elasticsearch/README.md
path: charts/elasticsearch/docs/backup-restore.md
version: 1.0
date: 2026-04-09
-->
