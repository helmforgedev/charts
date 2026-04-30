# Metabase Helm Chart

Deploy [Metabase](https://www.metabase.com) on Kubernetes using the official
[metabase/metabase](https://hub.docker.com/r/metabase/metabase) Docker image.
Open-source BI platform with visual data exploration, SQL editor, and shareable dashboards connecting to 60+ databases.

## Features

- **Visual data exploration** — point-and-click queries, no SQL required
- **SQL editor** — native SQL with autocomplete and snippets
- **60+ database connectors** — PostgreSQL, MySQL, BigQuery, Redshift, and more
- **PostgreSQL metadata store** — bundled subchart or external database
- **Auto-generated encryption key** — protects saved database credentials
- **JVM tuning** — configurable JAVA_OPTS for memory optimization
- **Ingress support** — TLS with cert-manager
- **Gateway API** — HTTPRoute for clusters running Envoy Gateway or similar
- **Dual-stack networking** — IPv4/IPv6 service support
- **External Secrets Operator** — ExternalSecret for Vault, AWS Secrets Manager, and more

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

## Dual-Stack Service

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

## Gateway API (HTTPRoute)

Requires Gateway API CRDs and a compatible controller (e.g. Envoy Gateway).

```yaml
gateway:
  enabled: true
  gatewayName: envoy-gateway
  gatewayNamespace: envoy-gateway-system
  hostnames:
    - metabase.example.com
```

> **Note:** `gateway.gatewayName` is required when `gateway.enabled=true`.

## External Secrets Operator (ESO)

Requires ESO installed. Set `metabase.existingSecret` so the chart-managed Secret is suppressed and the ExternalSecret is the single source of truth.

```yaml
metabase:
  existingSecret: metabase-eso-secret
  existingSecretKey: encryption-secret-key

externalSecrets:
  enabled: true
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  data:
    - secretKey: encryption-secret-key
      remoteRef:
        key: metabase/credentials
        property: encryption-secret-key
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
| `service.ipFamilyPolicy` | `~` | IP family policy (`SingleStack`, `PreferDualStack`, `RequireDualStack`) |
| `service.ipFamilies` | `[]` | IP families override (`IPv4`, `IPv6`) |
| `gateway.enabled` | `false` | Enable Gateway API HTTPRoute |
| `gateway.gatewayName` | `""` | Gateway name (required when `gateway.enabled=true`) |
| `gateway.gatewayNamespace` | `""` | Gateway namespace |
| `gateway.hostnames` | `[]` | HTTPRoute hostnames |
| `externalSecrets.enabled` | `false` | Render ExternalSecret resource |
| `externalSecrets.apiVersion` | `external-secrets.io/v1` | ExternalSecret API version |
| `externalSecrets.refreshInterval` | `"0"` | Refresh interval (`"0"` = one-time sync) |
| `externalSecrets.secretStoreRef.name` | `""` | SecretStore name (required when enabled) |
| `externalSecrets.secretStoreRef.kind` | `SecretStore` | SecretStore kind |
| `externalSecrets.data` | `[]` | Remote key mappings (must include encryption key entry) |

## More Information

- [Metabase documentation](https://www.metabase.com/docs/latest/)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/metabase)

<!-- @AI-METADATA
type: chart-readme
title: Metabase Helm Chart
description: README for the Metabase open-source BI platform Helm chart

keywords: metabase, bi, analytics, dashboard, visualization, postgresql, gateway-api, external-secrets, dual-stack

purpose: Chart installation, configuration, and usage documentation
scope: Chart

relations:
  - charts/metabase/values.yaml
path: charts/metabase/README.md
version: 1.1
date: 2026-04-30
-->
