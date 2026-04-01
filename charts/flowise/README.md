# Flowise

A Helm chart for deploying [Flowise](https://flowiseai.com/) on Kubernetes with a simple standalone mode or a scalable queue mode backed by Redis and PostgreSQL.

## Installation

### HTTPS Repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install flowise helmforge/flowise
```

### OCI Registry

```bash
helm install flowise oci://ghcr.io/helmforgedev/helm/flowise
```

## Features

- **Official Flowise image** based on `flowiseai/flowise`
- **Standalone mode** with SQLite and local storage for simple installs
- **Queue mode** with separate main and worker deployments for scalable processing
- **Bundled PostgreSQL and Redis** optional subcharts for queue mode
- **External database support** for PostgreSQL or MySQL
- **Local or S3 blob storage** with S3 required for queue mode
- **Ingress support** for the Flowise web UI
- **Values schema** `values.schema.json` validates chart inputs and improves Artifact Hub rendering

## Important Notes

- the chart validates application versions against both GitHub Releases and Docker Hub before pinning `appVersion`
- `appVersion` is pinned to `3.1.1`, confirmed on the official GitHub release `flowise@3.1.1` and the official Docker Hub tag `3.1.1`
- `architecture.mode=queue` requires Redis, a SQL database, `storage.type=s3`, and `persistence.enabled=false`
- standalone mode defaults to SQLite and local storage, which is intentionally single-node oriented

## Supported Architectures

### Standalone

- one or more UI-only pods when using shared external services and S3
- default local-first mode uses SQLite and a local PVC, so it is effectively single replica

### Queue

- main Flowise servers run the web UI and enqueue jobs
- worker deployments process queue jobs asynchronously
- Redis is mandatory
- SQLite is not supported
- S3-compatible storage is mandatory for shared blob storage

## Quick Start

### Standalone

```bash
helm install flowise oci://ghcr.io/helmforgedev/helm/flowise \
  --set ingress.enabled=true \
  --set ingress.ingressClassName=traefik \
  --set ingress.hosts[0].host=flowise.example.com \
  --set ingress.hosts[0].paths[0].path=/ \
  --set ingress.hosts[0].paths[0].pathType=Prefix
```

### Queue Mode

```bash
helm install flowise oci://ghcr.io/helmforgedev/helm/flowise \
  --set architecture.mode=queue \
  --set persistence.enabled=false \
  --set postgresql.enabled=true \
  --set redis.enabled=true \
  --set storage.type=s3 \
  --set storage.s3.bucketName=flowise \
  --set storage.s3.accessKeyId=minio \
  --set storage.s3.secretAccessKey=secret123
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `architecture.mode` | `standalone` | Flowise topology: `standalone` or `queue` |
| `flowise.replicaCount` | `1` | Number of main Flowise server replicas |
| `queue.worker.replicaCount` | `1` | Number of worker replicas in queue mode |
| `database.mode` | `auto` | Database mode: `sqlite`, `external`, or `postgresql` |
| `postgresql.enabled` | `false` | Deploy PostgreSQL subchart |
| `redis.enabled` | `false` | Deploy Redis subchart |
| `storage.type` | `local` | Blob storage type: `local` or `s3` |
| `persistence.enabled` | `true` | Persist local Flowise data |
| `flowise.appUrl` | `""` | Public Flowise URL |
| `service.port` | `3000` | Service port exposed by Kubernetes |
| `ingress.enabled` | `false` | Enable ingress exposure |

## More Information

- [Architecture Notes](docs/architecture.md)
- [Standalone Example](examples/standalone.yaml)
- [Queue Example](examples/queue-s3.yaml)
- [Source code and full values reference](https://github.com/helmforgedev/charts/tree/main/charts/flowise)

<!-- @AI-METADATA
type: chart-readme
title: Flowise
description: Installation guide, values reference, and operational overview for the Flowise Helm chart

keywords: flowise, ai, llm, agents, redis, postgresql, sqlite, s3, helm

purpose: User-facing chart documentation with install instructions, examples, and values reference
scope: Chart

relations:
  - charts/flowise/docs/architecture.md
path: charts/flowise/README.md
version: 1.0
date: 2026-03-31
-->
