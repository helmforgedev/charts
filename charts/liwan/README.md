<!-- SPDX-License-Identifier: Apache-2.0 -->

# Liwan Helm Chart

Deploy [Liwan](https://liwan.dev) on Kubernetes using the official
[ghcr.io/explodingcamera/liwan](https://github.com/explodingcamera/liwan/pkgs/container/liwan)
container image. Ultra-lightweight privacy-first web analytics written in Rust with embedded DuckDB.

## Features

- **Ultra-lightweight** — single Rust binary, minimal CPU and memory usage
- **Zero dependencies** — DuckDB embedded, no external database needed
- **Privacy-first** — no cookies, no personal data collection
- **Non-root** — runs as UID 1000 by default
- **Persistent storage** — DuckDB database and GeoIP data on PVC
- **Ingress support** — TLS with cert-manager
- **Gateway API support** — optional HTTPRoute for native Kubernetes routing
- **Dual-stack ready Service** — optional `ipFamilyPolicy` and `ipFamilies`

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
# values.yaml - default values are sufficient
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
| `image.repository` | `ghcr.io/explodingcamera/liwan` | Liwan image repository |
| `image.tag` | `"1.5.0"` | Liwan image tag |
| `liwan.port` | `9042` | Application port |
| `liwan.baseUrl` | `""` | Public base URL |
| `persistence.enabled` | `true` | Enable persistence for /data |
| `persistence.size` | `2Gi` | PVC size |
| `ingress.enabled` | `false` | Enable ingress |
| `service.port` | `80` | Service port |
| `service.ipFamilyPolicy` | `null` | Service IP family policy |
| `service.ipFamilies` | `[]` | Ordered Service IP families |
| `gatewayAPI.enabled` | `false` | Render a Gateway API HTTPRoute |

## Gateway API Example

```yaml
gatewayAPI:
  enabled: true
  parentRefs:
    - name: shared-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - analytics.example.com
```

## Dual-Stack Service Example

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

## Upgrade Notes

Liwan `1.5.0` is published in GHCR and includes the unreleased upstream changelog entries after `v1.4.0`,
including additional trusted proxy/header options, new dimensions, DuckDB updates, and startup locking fixes.
The chart keeps the single-replica `Recreate` strategy because DuckDB remains single-writer storage.

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
