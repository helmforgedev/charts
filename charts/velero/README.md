# Velero Helm Chart

Deploy [Velero](https://velero.io/) on Kubernetes for cluster backup, restore, migration, and filesystem backup workflows.

This chart uses the official `velero/velero` image and is intentionally centered on a clear v1 scope:

- explicit plugin init containers
- S3-compatible object storage as the main path
- optional `BackupStorageLocation`, `VolumeSnapshotLocation`, and `Schedule` resources
- optional node-agent DaemonSet for filesystem backup

## Features

- **Official `velero/velero` image** pinned to the latest stable Velero release
- **Official CRDs included** through the chart `crds/` directory
- **AWS plugin by default** for AWS S3 and S3-compatible providers such as MinIO
- **BackupStorageLocation resources** rendered directly from chart values
- **VolumeSnapshotLocation resources** rendered when snapshot providers are configured
- **Schedule resources** for recurring backups
- **Optional node-agent** for filesystem backup workflows
- **Optional ServiceMonitor** for Prometheus Operator

## Installation

### HTTPS repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install velero helmforge/velero -n velero --create-namespace -f values.yaml
```

### OCI registry

```bash
helm install velero oci://ghcr.io/helmforgedev/helm/velero -n velero --create-namespace -f values.yaml
```

## S3-Compatible Example

```yaml
credentials:
  secretContents: |
    [default]
    aws_access_key_id=minioadmin
    aws_secret_access_key=minioadmin123

configuration:
  backupStorageLocations:
    - name: default
      provider: aws
      bucket: velero
      default: true
      config:
        region: minio
        s3Url: http://minio.minio.svc.cluster.local:9000
        s3ForcePathStyle: true
        insecureSkipTLSVerify: true

nodeAgent:
  enabled: true
```

## Scheduled Backup Example

```yaml
schedules:
  - name: daily
    schedule: "0 3 * * *"
    template:
      ttl: 168h
      includedNamespaces:
        - apps
      snapshotVolumes: false
      defaultVolumesToFsBackup: true
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `docker.io/velero/velero` | Velero server image |
| `plugins.aws.tag` | `v1.14.0` | Default AWS/S3 plugin image tag |
| `credentials.useSecret` | `true` | Mount credentials from a secret |
| `credentials.existingSecret` | `""` | Existing credentials secret |
| `configuration.backupStorageLocations` | one empty default entry | Backup storage definitions |
| `configuration.volumeSnapshotLocations` | `[]` | Snapshot storage definitions |
| `configuration.defaultVolumesToFsBackup` | `false` | Default filesystem backup mode |
| `nodeAgent.enabled` | `false` | Deploy filesystem backup DaemonSet |
| `schedules` | `[]` | Schedule resources created by the chart |
| `metrics.serviceMonitor.enabled` | `false` | Create a ServiceMonitor |

## Resources Generated

| Resource | Condition |
|----------|-----------|
| ServiceAccount | `serviceAccount.server.create` |
| ClusterRoleBinding | `rbac.create` and `rbac.clusterAdministrator` |
| Secret | `credentials.useSecret` and no `credentials.existingSecret` |
| Deployment | Always |
| DaemonSet | `nodeAgent.enabled` |
| Service | `metrics.enabled` |
| ServiceMonitor | `metrics.serviceMonitor.enabled` |
| BackupStorageLocation | one per `configuration.backupStorageLocations` entry |
| VolumeSnapshotLocation | one per `configuration.volumeSnapshotLocations` entry |
| Schedule | one per `schedules` entry |

## Notes

- this v1 chart is intentionally focused on clear install and configuration flows, not on abstracting every Velero provider combination
- for S3-compatible storage, use the AWS plugin with explicit `s3Url` and `s3ForcePathStyle` settings when required by the provider
- if you enable `nodeAgent`, validate hostPath and Pod Security expectations in your cluster before relying on filesystem backups

## More Information

- [S3-compatible setup](docs/s3-compatible.md)
- [Filesystem backup](docs/filesystem-backup.md)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/velero)

<!-- @AI-METADATA
type: chart-readme
title: Velero Helm Chart
description: Helm chart for deploying Velero on Kubernetes

keywords: velero, backup, restore, disaster-recovery, s3, kubernetes

purpose: User-facing chart documentation with install, features, examples, and values reference
scope: Chart

relations:
  - charts/velero/values.yaml
  - charts/velero/docs/s3-compatible.md
  - charts/velero/docs/filesystem-backup.md
path: charts/velero/README.md
version: 1.0
date: 2026-03-31
-->
