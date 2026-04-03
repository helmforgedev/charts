# Cronicle Helm Chart

Deploy [Cronicle](https://github.com/jhuckaby/Cronicle) on Kubernetes using the [soulteary/cronicle](https://hub.docker.com/r/soulteary/cronicle) community container image. Multi-server task scheduler and runner with a built-in web UI — supports scheduled jobs, shell commands, HTTP requests, and plugins with zero external dependencies.

## Features

- **Web UI** — built-in dashboard for managing schedules, viewing logs, and monitoring jobs
- **Zero dependencies** — filesystem-based storage, no external database needed
- **Configurable** — JSON config via ConfigMap, secret key via Secret
- **Auto-discovery** — optional UDP port for multi-server setups
- **Persistent storage** — job data, history, and state on PVC
- **Ingress support** — TLS with cert-manager, supports traefik or nginx

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install cronicle helmforge/cronicle -f values.yaml
```

**OCI registry:**

```bash
helm install cronicle oci://ghcr.io/helmforgedev/helm/cronicle -f values.yaml
```

## Basic Example

```yaml
# values.yaml — default values are sufficient for a single-server setup
# Filesystem storage, auto-generated secret key
```

After deploying:

```bash
kubectl port-forward svc/<release>-cronicle 3012:80
# Open http://localhost:3012
# Default credentials: admin / admin
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `cronicle.port` | `3012` | HTTP web UI port |
| `cronicle.discoveryPort` | `3014` | UDP auto-discovery port |
| `cronicle.discoveryEnabled` | `false` | Enable UDP discovery service port |
| `cronicle.baseUrl` | `"http://localhost:3012"` | Public base URL |
| `cronicle.emailFrom` | `"cronicle@localhost"` | Email sender for notifications |
| `cronicle.smtpHostname` | `"localhost"` | SMTP server hostname |
| `cronicle.jobMemoryMax` | `1073741824` | Max memory per job (bytes, 1 GB) |
| `cronicle.maxJobs` | `0` | Max concurrent jobs (0 = unlimited) |
| `secret.create` | `true` | Auto-generate session encryption key |
| `secret.existingSecret` | `""` | Use an existing secret |
| `persistence.enabled` | `true` | Enable persistence for /opt/cronicle/data |
| `persistence.size` | `5Gi` | PVC size |
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `traefik` | Ingress class (traefik, nginx) |
| `service.port` | `80` | Service port |

## Limitations

- **Single instance recommended** — filesystem storage is single-writer; horizontal scaling requires shared storage or external database
- **ReadWriteOnce** — default PVC uses ReadWriteOnce due to filesystem storage
- **Community image** — uses `soulteary/cronicle` as Cronicle does not publish an official container image

## More Information

- [Cronicle documentation](https://github.com/jhuckaby/Cronicle)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/cronicle)

<!-- @AI-METADATA
type: chart-readme
title: Cronicle Helm Chart
description: README for the Cronicle multi-server task scheduler Helm chart

keywords: cronicle, scheduler, task-runner, cron, job-scheduler

purpose: Chart installation, configuration, and usage documentation
scope: Chart

relations:
  - charts/cronicle/values.yaml
path: charts/cronicle/README.md
version: 1.0
date: 2026-04-03
-->
