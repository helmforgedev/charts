# Metabase Helm Chart

Deploy [Metabase](https://www.metabase.com) on Kubernetes using the official [metabase/metabase](https://hub.docker.com/r/metabase/metabase) Docker image. Open-source BI platform with visual data exploration, SQL editor, and shareable dashboards connecting to 60+ databases.

## Features

- **Visual data exploration** — point-and-click queries, no SQL required
- **SQL editor** — native SQL with autocomplete and snippets
- **60+ database connectors** — PostgreSQL, MySQL, BigQuery, Redshift, and more
- **PostgreSQL metadata store** — bundled subchart or external database
- **Auto-generated encryption key** — protects saved database credentials
- **JVM tuning** — configurable JAVA_OPTS for memory optimization
- **Ingress support** — TLS with cert-manager

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install metabase helmforge/metabase -f values.yaml
```

**OCI registry:**

```bash
helm install metabase oci://ghcr.io/helmforgedev/helm/metabase -f values.yaml
```

## Basic Example

```yaml
# values.yaml — default values deploy with bundled PostgreSQL
# No configuration needed for a basic setup
```

After deploying, access Metabase:

```bash
kubectl port-forward svc/<release>-metabase 3000:80
# Open http://localhost:3000 to complete the setup wizard
```

## External Database

```yaml
postgresql:
  enabled: false

database:
  external:
    host: postgres.example.com
    name: metabase
    username: metabase
    existingSecret: metabase-db-credentials
```

## JVM Tuning

```yaml
metabase:
  javaOpts: "-Xmx2g -Xms1g"

resources:
  requests:
    memory: 2Gi
  limits:
    memory: 3Gi
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `metabase.port` | `3000` | Application port |
| `metabase.encryptionSecretKey` | `""` | Encryption key (auto-generated) |
| `metabase.siteUrl` | `""` | Public site URL |
| `metabase.javaTimezone` | `UTC` | Java timezone |
| `metabase.javaOpts` | `""` | JVM memory options |
| `postgresql.enabled` | `true` | Deploy PostgreSQL subchart |
| `ingress.enabled` | `false` | Enable ingress |
| `service.port` | `80` | Service port |

## More Information

- [Metabase documentation](https://www.metabase.com/docs/latest/)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/metabase)

<!-- @AI-METADATA
type: chart-readme
title: Metabase Helm Chart
description: README for the Metabase open-source BI platform Helm chart

keywords: metabase, bi, analytics, dashboard, visualization, postgresql

purpose: Chart installation, configuration, and usage documentation
scope: Chart

relations:
  - charts/metabase/values.yaml
path: charts/metabase/README.md
version: 1.0
date: 2026-04-01
-->
