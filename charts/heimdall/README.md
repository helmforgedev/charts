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
- **Hardened Defaults** — no API token, restricted capabilities, seccomp, and ingress NetworkPolicy

## Documentation

- [Chart Design](DESIGN.md)
- [Operations Guide](docs/operations.md)
- [Backup Guide](docs/backup.md)
- [Security Guide](docs/security.md)
- [Heimdall Source](https://github.com/linuxserver/Heimdall)

### Security Scan: `heimdall`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **72.73%** |

> Security posture acceptable with operator-provided resource limits, security contexts, and network policy.

## Configuration

Set a non-empty `image.repository` and `image.tag`; the chart rejects empty values before creating a workload.

`heimdall.containerPort` configures the real NGINX listener. It is independent
from `service.port`, which controls only the Kubernetes Service port.

## Examples

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

### Heimdall Settings

| Key | Default | Description |
|-----|---------|-------------|
| `heimdall.puid` | `1000` | User ID for file permissions |
| `heimdall.pgid` | `1000` | Group ID for file permissions |
| `heimdall.timezone` | `"UTC"` | Timezone |
| `heimdall.containerPort` | `80` | HTTP port used by the Heimdall NGINX process |

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

### Security

The chart disables Kubernetes API token automount, applies `RuntimeDefault`
seccomp, disables privilege escalation, minimizes Linux capabilities, and
creates an ingress NetworkPolicy by default. The main process still starts as
root because the LinuxServer `/init` sequence must prepare `/config` before
switching to `PUID`/`PGID`; see the [Security Guide](docs/security.md) for the
documented exception and network boundaries.

| Key | Default | Description |
|-----|---------|-------------|
| `serviceAccount.create` | `false` | Create a dedicated ServiceAccount |
| `serviceAccount.automountServiceAccountToken` | `false` | Mount a Kubernetes API token in the pod |
| `networkPolicy.enabled` | `true` | Restrict server ingress to the named HTTP port |
| `networkPolicy.extraIngress` | `[]` | Additional complete ingress rules |
| `podSecurityContext.seccompProfile.type` | `RuntimeDefault` | Pod seccomp profile |
| `securityContext.allowPrivilegeEscalation` | `false` | Permit privilege escalation |
| `securityContext.readOnlyRootFilesystem` | `false` | Read-only root filesystem; disabled for s6-overlay compatibility |

### Probes and Scheduling

Startup, readiness, and liveness probes use the named `http` port and expose
path, delay, period, timeout, and failure threshold settings in `values.yaml`.
Resources, scheduling, labels, annotations, extra volumes, mounts, manifests,
and image pull secrets remain fully operator-configurable. The complete values
contract is documented inline in [`values.yaml`](values.yaml) and enforced by
[`values.schema.json`](values.schema.json).

## Architecture

One Deployment runs LinuxServer's NGINX, PHP-FPM, and Heimdall processes. A
single persistent `/config` volume contains SQLite data, settings, and assets;
the Deployment therefore uses `Recreate` and intentionally does not expose a
replica setting. The optional backup CronJob archives that same volume to S3.
See [Chart Design](DESIGN.md) for boundaries and tradeoffs.

## Troubleshooting

Inspect readiness, logs, events, and the effective NGINX listener:

```bash
kubectl get pods -l app.kubernetes.io/instance=<release>
kubectl logs -l app.kubernetes.io/instance=<release> --all-containers --tail=100
kubectl get events --sort-by=.lastTimestamp
kubectl exec deploy/<release>-heimdall -c heimdall -- grep 'listen .* default_server' /config/nginx/site-confs/default.conf
```

Write failures under `/config` usually mean `heimdall.puid` or `heimdall.pgid`
does not match the volume's ownership. Connection failures on a custom listener
should be checked against both `heimdall.containerPort` and `service.port`.

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

relations:
  - charts/heimdall/DESIGN.md
  - charts/heimdall/docs/operations.md
  - charts/heimdall/docs/backup.md
  - charts/heimdall/values.yaml
path: charts/heimdall/README.md
version: 1.0
date: 2026-03-31
-->
