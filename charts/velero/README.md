<!-- SPDX-License-Identifier: Apache-2.0 -->

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
- **Restricted server and plugin containers** with non-root identities,
  read-only root filesystems, dropped capabilities, and RuntimeDefault seccomp
- **NetworkPolicy enabled by default** for the server metrics endpoint
- **Configurable metrics listener and Service ports** connected by a named
  target port
- **Startup, readiness, and liveness probes** against the metrics listener
- **Extra objects support** for carefully reviewed provider-specific resources

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

For a complete hardened configuration, see
[`examples/production.yaml`](examples/production.yaml).

## Metrics Port Example

The process listener is independent from the Service port. The Service uses a
named target so both values can change safely:

```yaml
metrics:
  containerPort: 9085
  service:
    port: 9090
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `docker.io/velero/velero` | Velero server image |
| `image.tag` | `v1.18.4` | Velero server image tag |
| `plugins.aws.tag` | `v1.14.0` | Default AWS/S3 plugin image tag |
| `credentials.useSecret` | `true` | Mount credentials when `existingSecret`, `name`, or `secretContents` is set |
| `credentials.existingSecret` | `""` | Existing credentials secret |
| `configuration.backupStorageLocations` | one empty default entry | Backup storage definitions |
| `configuration.volumeSnapshotLocations` | `[]` | Snapshot storage definitions |
| `configuration.defaultVolumesToFsBackup` | `false` | Default filesystem backup mode |
| `nodeAgent.enabled` | `false` | Deploy filesystem backup DaemonSet |
| `schedules` | `[]` | Schedule resources created by the chart |
| `metrics.containerPort` | `8085` | Port listened on by the Velero process |
| `metrics.service.port` | `8085` | Metrics Service port |
| `service.ipFamilyPolicy` | `""` | Optional metrics Service IP family policy |
| `metrics.serviceMonitor.enabled` | `false` | Create a ServiceMonitor |
| `networkPolicy.enabled` | `true` | Isolate the Velero server pod |
| `networkPolicy.allowExternalEgress` | `true` | Allow Kubernetes API and object-storage egress |
| `extraManifests` | `[]` | Additional manifests rendered with `tpl` |

## Architecture Guides

- [Design](DESIGN.md)
- [Operations](docs/operations.md)
- [Security](docs/security.md)
- [S3-compatible storage](docs/s3-compatible.md)
- [Filesystem backup](docs/filesystem-backup.md)

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
| NetworkPolicy | `networkPolicy.enabled` |
| BackupStorageLocation | one per `configuration.backupStorageLocations` entry |
| VolumeSnapshotLocation | one per `configuration.volumeSnapshotLocations` entry |
| Schedule | one per `schedules` entry |
| Extra manifests | one per `extraManifests` entry |

## Notes

- this v1 chart is intentionally focused on clear install and configuration flows, not on abstracting every Velero provider combination
- for S3-compatible storage, use the AWS plugin with explicit `s3Url` and `s3ForcePathStyle` settings when required by the provider
- if you enable `nodeAgent`, validate hostPath and Pod Security expectations in your cluster before relying on filesystem backups
- the server and default AWS plugin run as non-root with restricted security
  contexts; the optional node-agent runs as UID 0 because filesystem backup
  requires kubelet host-path access
- NetworkPolicy egress is open by default because the Kubernetes API and
  object-storage endpoints are installation-specific; set
  `networkPolicy.allowExternalEgress=false` before adding a restrictive
  environment-specific policy, because NetworkPolicy rules are additive
- when the node-agent uses Kopia, the chart mounts ephemeral writable
  `/home/cnb/udmrepo` and `/home/cnb/.cache` paths in the server and node-agent
  while keeping their root filesystems read-only

Velero v1.18.4 fixes a backup queue that could remain stuck when a dequeued
backup completed during its status patch. Review the
[upstream release](https://github.com/velero-io/velero/releases/tag/v1.18.4)
before upgrading production recovery infrastructure.

## Troubleshooting

If the Deployment is not ready, inspect the server logs and the status of the
configured backup storage locations:

```bash
kubectl logs deployment/velero -n velero --all-containers
kubectl get backupstoragelocations.velero.io -n velero -o yaml
```

An unavailable backup storage location normally indicates invalid provider
credentials, an unreachable endpoint, a missing bucket, or an incompatible
plugin. If probes fail after changing ports, confirm
`metrics.containerPort` matches the `--metrics-address` argument in the pod;
`metrics.service.port` affects only the Service-facing port. See the
[operations guide](docs/operations.md) for recovery checks and upgrade notes.

## Security Scan

### Security Scan: `velero`

| Framework | Score |
|-----------|-------|
| MITRE + NSA + SOC2 | **77.27273%** |

Security posture acceptable.

## More Information

- [S3-compatible setup](docs/s3-compatible.md)
- [Filesystem backup](docs/filesystem-backup.md)
- [Operations guide](docs/operations.md)
- [Security guide](docs/security.md)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/velero)
