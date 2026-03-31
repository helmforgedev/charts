# Heimdall

A Helm chart for deploying [Heimdall](https://heimdall.site/) application dashboard on Kubernetes using the [`linuxserver/heimdall`](https://hub.docker.com/r/linuxserver/heimdall) Docker image.

## Installation

### HTTPS Repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install heimdall helmforge/heimdall
```

### OCI Registry

```bash
helm install heimdall oci://ghcr.io/helmforgedev/helm/heimdall
```

## Features

- **LinuxServer.io Image** — based on the maintained `linuxserver/heimdall` container
- **Persistent Storage** — SQLite database and settings stored in `/config`
- **S3-Compatible Backup** — CronJob that creates a tar archive of `/config` and uploads to any S3 endpoint
- **Ingress Support** — configurable ingress with TLS for HTTPS access
- **PUID/PGID** — file ownership control for the container

## Configuration

### Minimal

```yaml
# Just install — defaults work out of the box
```

### Production with Ingress and Backup

```yaml
heimdall:
  timezone: "America/New_York"

ingress:
  enabled: true
  ingressClassName: traefik
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: dashboard.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: heimdall-tls
      hosts:
        - dashboard.example.com

backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://s3.amazonaws.com
    bucket: my-backups
    prefix: heimdall
    existingSecret: heimdall-s3-credentials
```

## Parameters

### Heimdall

| Key | Default | Description |
|-----|---------|-------------|
| `heimdall.puid` | `1000` | User ID for file permissions |
| `heimdall.pgid` | `1000` | Group ID for file permissions |
| `heimdall.timezone` | `"UTC"` | Timezone |

### Persistence

| Key | Default | Description |
|-----|---------|-------------|
| `persistence.enabled` | `true` | Enable persistent storage for /config |
| `persistence.size` | `1Gi` | Volume size |
| `persistence.existingClaim` | `""` | Use an existing PVC |

### S3 Backup

| Key | Default | Description |
|-----|---------|-------------|
| `backup.enabled` | `false` | Enable S3 backup CronJob |
| `backup.schedule` | `"0 3 * * *"` | Cron schedule |
| `backup.s3.endpoint` | `""` | S3-compatible endpoint URL |
| `backup.s3.bucket` | `""` | S3 bucket name |
| `backup.s3.prefix` | `heimdall` | S3 key prefix |
| `backup.s3.existingSecret` | `""` | Existing secret with S3 credentials |

### Service

| Key | Default | Description |
|-----|---------|-------------|
| `service.type` | `ClusterIP` | Service type |
| `service.port` | `80` | Service port |

### Ingress

| Key | Default | Description |
|-----|---------|-------------|
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `""` | Ingress class (`traefik`, `nginx`, etc.) |
| `ingress.hosts` | `[]` | Ingress hosts and paths |
| `ingress.tls` | `[]` | TLS configuration |

## Notes

- Heimdall uses **SQLite** internally — only a single replica is supported
- the deployment uses `Recreate` strategy to avoid SQLite locking issues during upgrades
- backup creates a tar archive of the entire `/config` directory including the SQLite database
- for file permission issues, adjust `heimdall.puid` and `heimdall.pgid` to match your storage

## More Information

- [Source code and full values reference](https://github.com/helmforgedev/charts/tree/main/charts/heimdall)

<!-- @AI-METADATA
type: chart-readme
title: Heimdall
description: Installation guide, values reference, and operational overview for the Heimdall Helm chart

keywords: heimdall, dashboard, homepage, launcher, self-hosted, helm, kubernetes

purpose: User-facing chart documentation with install, examples, and values reference
scope: Chart

relations: []
path: charts/heimdall/README.md
version: 1.0
date: 2026-03-31
-->
