# Liwan Helm Chart

Deploy [Liwan](https://liwan.dev) on Kubernetes using the official [ghcr.io/explodingcamera/liwan](https://github.com/explodingcamera/liwan/pkgs/container/liwan) container image. Ultra-lightweight privacy-first web analytics written in Rust with embedded DuckDB — runs on minimal resources with zero external dependencies.

## Features

- **Ultra-lightweight** — single Rust binary, minimal CPU and memory usage
- **Zero dependencies** — DuckDB embedded, no external database needed
- **Privacy-first** — no cookies, no personal data collection
- **Non-root** — runs as UID 1000 by default
- **Persistent storage** — DuckDB database and GeoIP data on PVC
- **Ingress support** — TLS with cert-manager

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install liwan helmforge/liwan -f values.yaml
```

**OCI registry:**

```bash
helm install liwan oci://ghcr.io/helmforgedev/helm/liwan -f values.yaml
```

## Basic Example

```yaml
# values.yaml — default values are sufficient
# DuckDB embedded, no database needed
```

After deploying:

```bash
kubectl port-forward svc/<release>-liwan 9042:80
# Open http://localhost:9042
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `liwan.port` | `9042` | Application port |
| `liwan.baseUrl` | `""` | Public base URL |
| `persistence.enabled` | `true` | Enable persistence for /data |
| `persistence.size` | `2Gi` | PVC size |
| `ingress.enabled` | `false` | Enable ingress |
| `service.port` | `80` | Service port |

## Limitations

- **Single instance only** — DuckDB is single-writer, horizontal scaling is not supported
- **ReadWriteOnce** — PVC must be ReadWriteOnce due to DuckDB limitations

## More Information

- [Liwan documentation](https://liwan.dev)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/liwan)

<!-- @AI-METADATA
type: chart-readme
title: Liwan Helm Chart
description: README for the Liwan ultra-lightweight web analytics Helm chart

keywords: liwan, analytics, privacy, duckdb, lightweight, rust

purpose: Chart installation, configuration, and usage documentation
scope: Chart

relations:
  - charts/liwan/values.yaml
path: charts/liwan/README.md
version: 1.0
date: 2026-04-01
-->
