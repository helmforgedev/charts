# Umami Helm Chart

Deploy [Umami](https://umami.is), a privacy-first web analytics platform, on Kubernetes using the official
`ghcr.io/umami-software/umami` image and HelmForge production patterns.

The chart supports a fast development install with bundled PostgreSQL and a production path with external
PostgreSQL, managed secrets, ingress or Gateway API, NetworkPolicy, PodDisruptionBudget, S3-compatible database
backups, and explicit Umami runtime options.

## Features

- Privacy-first analytics with no cookies by default.
- Official Umami image and configurable image pull policy.
- Bundled `helmforge/postgresql` subchart for quick starts.
- External PostgreSQL support for managed or operator-owned databases.
- Structured Umami settings for telemetry, updates, bot checks, SSL forwarding, base paths, tracker names, CORS, and frame allowlists.
- Optional `external-secrets.io/v1` resources for APP_SECRET, database password, and S3 backup credentials.
- Ingress and Kubernetes Gateway API `HTTPRoute` exposure options.
- Dual-stack service controls through `ipFamilyPolicy` and `ipFamilies`.
- Optional NetworkPolicy with ingress and egress controls.
- Optional PodDisruptionBudget for multi-replica deployments.
- S3-compatible PostgreSQL backup CronJob.
- Focused Helm unit tests and CI values for default, external DB, backup, ingress, Gateway API, dual-stack, External Secrets, NetworkPolicy, and production examples.

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install umami helmforge/umami --namespace umami --create-namespace
```

OCI registry:

```bash
helm install umami oci://ghcr.io/helmforgedev/helm/umami --namespace umami --create-namespace
```

Access a default install:

```bash
kubectl port-forward -n umami svc/umami-umami 3000:80
```

Open `http://localhost:3000` and sign in with Umami's initial credentials:

- Username: `admin`
- Password: `umami`

Change the password immediately after first login.

## Development Defaults

The default values are intentionally simple:

- `postgresql.enabled=true`
- one Umami replica
- generated APP_SECRET and database password
- ClusterIP service
- no public ingress
- no NetworkPolicy
- no PDB
- telemetry and update checks disabled

This is useful for local clusters, demos, and CI smoke tests. It is not a production-ready posture by itself.

## Production Path

For production, prefer:

- external or operator-managed PostgreSQL
- a stable APP_SECRET stored in Kubernetes Secret or External Secrets Operator
- TLS termination through Gateway API or ingress
- `FORCE_SSL=true` when the proxy terminates HTTPS
- `CLIENT_IP_HEADER` aligned with your ingress controller or gateway
- multiple replicas with PDB
- explicit resource requests and memory limits
- NetworkPolicy ingress and egress controls
- backup CronJob or a database-native backup solution

Start from:

```bash
helm install umami helmforge/umami \
  --namespace umami \
  --create-namespace \
  -f charts/umami/examples/production.yaml
```

## External PostgreSQL

Disable the bundled database and point Umami at a managed PostgreSQL endpoint:

```yaml
postgresql:
  enabled: false

database:
  external:
    host: postgres-primary.database.svc.cluster.local
    port: 5432
    name: umami
    username: umami
    existingSecret: umami-db
    existingSecretPasswordKey: database-password
    init:
      enabled: true
      adminUsername: postgres
      adminExistingSecret: postgres-admin
```

Create the secret:

```bash
kubectl create secret generic umami-db \
  --from-literal=database-password='replace-me'
```

Umami creates the `pgcrypto` extension during its first migration. Many managed databases require an owner or
administrative account to create extensions. When the application user cannot do that, enable
`database.external.init.enabled` and provide an admin Secret. The init container runs before Umami starts and only
executes the SQL configured in `database.external.init.sql`.

## External Secrets

Use External Secrets Operator when credentials are stored in Vault, AWS Secrets Manager, GCP Secret Manager, Azure Key Vault, or another supported backend.

```yaml
postgresql:
  enabled: false

externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
    kind: ClusterSecretStore
  app:
    enabled: true
    targetName: umami-app
    appSecretRemoteRef:
      key: prod/umami/app
      property: appSecret
  database:
    enabled: true
    targetName: umami-db
    passwordRemoteRef:
      key: prod/umami/database
      property: password
```

The chart renders `external-secrets.io/v1` resources and consumes the generated Kubernetes Secrets.

## Gateway API

Gateway API is available through `gatewayAPI.enabled=true`:

```yaml
gatewayAPI:
  enabled: true
  parentRefs:
    - name: public-gateway
      namespace: gateway-system
  hostnames:
    - analytics.example.com
```

Use ingress instead when your cluster standardizes on `networking.k8s.io/v1` Ingress.

## Service Dual Stack

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

Dual-stack requires a cluster and CNI configured for IPv4/IPv6.

## NetworkPolicy

NetworkPolicy is opt-in:

```yaml
networkPolicy:
  enabled: true
  ingress:
    allowSameNamespace: true
  egress:
    enabled: true
    allowDNS: true
    allowSameNamespaceDatabase: true
    allowHTTPS: true
```

Some local CNIs enforce traffic through pod CIDRs differently when testing through Services. In those clusters, add an
explicit ingress peer:

```yaml
networkPolicy:
  ingress:
    allowSameNamespace: false
    extraFrom:
      - ipBlock:
          cidr: 10.42.0.0/16
```

## Umami Runtime Settings

Common structured settings:

| Value | Umami env var | Default | Purpose |
| --- | --- | --- | --- |
| `umami.disableTelemetry` | `DISABLE_TELEMETRY` | `true` | Disable Umami telemetry. |
| `umami.disableUpdates` | `DISABLE_UPDATES` | `true` | Disable update checks. |
| `umami.disableBotCheck` | `DISABLE_BOT_CHECK` | `false` | Disable built-in bot filtering when needed. |
| `umami.forceSSL` | `FORCE_SSL` | `false` | Trust proxy HTTPS and generate secure URLs. |
| `umami.clientIpHeader` | `CLIENT_IP_HEADER` | `""` | Header used to detect client IP behind a proxy. |
| `umami.collectApiEndpoint` | `COLLECT_API_ENDPOINT` | `""` | Custom collect endpoint. |
| `umami.trackerScriptName` | `TRACKER_SCRIPT_NAME` | `""` | Custom tracker script file name. |
| `umami.allowedFrameUrls` | `ALLOWED_FRAME_URLS` | `""` | Allow specific frame embed URLs. |
| `umami.corsMaxAge` | `CORS_MAX_AGE` | `""` | CORS preflight cache duration. |

Use `extraEnv` for Umami settings not yet modeled by the chart.

Sub-path hosting requires a custom Umami image built with the upstream `BASE_PATH` build-time variable.
The chart does not set `BASE_PATH` as a runtime environment variable for the stock image.

## Backup

The chart can create a PostgreSQL dump CronJob and upload it to S3-compatible storage:

```yaml
backup:
  enabled: true
  schedule: "0 2 * * *"
  s3:
    endpoint: https://s3.example.com
    bucket: umami-backups
    existingSecret: umami-backup
```

The referenced secret must contain the keys configured by `backup.s3.existingSecretAccessKeyKey` and
`backup.s3.existingSecretSecretKeyKey`.

For production, test restore procedures outside Helm. Backups without restore validation are only partial protection.

## Key Values

| Key | Default | Description |
| --- | --- | --- |
| `replicaCount` | `1` | Number of Umami pods. |
| `image.repository` | `ghcr.io/umami-software/umami` | Umami image repository. |
| `image.tag` | `3.0.3` | Umami image tag. |
| `service.type` | `ClusterIP` | Kubernetes service type. |
| `service.ipFamilyPolicy` | `""` | Optional service IP family policy. |
| `service.ipFamilies` | `[]` | Optional service IP families. |
| `ingress.enabled` | `false` | Enable Ingress. |
| `gatewayAPI.enabled` | `false` | Enable Gateway API HTTPRoute. |
| `postgresql.enabled` | `true` | Deploy bundled HelmForge PostgreSQL. |
| `database.external.host` | `""` | External PostgreSQL host when bundled PostgreSQL is disabled. |
| `database.external.init.enabled` | `false` | Run optional external database preparation SQL before Umami starts. |
| `externalSecrets.enabled` | `false` | Render ExternalSecret resources. |
| `networkPolicy.enabled` | `false` | Render NetworkPolicy. |
| `pdb.enabled` | `false` | Render PodDisruptionBudget. |
| `backup.enabled` | `false` | Enable S3-compatible backup CronJob. |
| `serviceAccount.automountServiceAccountToken` | `false` | Control service account token mounting. |
| `extraInitContainers` | `[]` | Additional init containers for preparing shared volumes before Umami starts. |
| `extraVolumes` / `extraVolumeMounts` | `[]` | Additional pod volumes and Umami container mounts, such as GeoIP databases or custom assets. |

## Examples

- `examples/production.yaml` - production-oriented values with external PostgreSQL, Gateway API, NetworkPolicy, and PDB.
- `examples/external-postgresql.yaml` - managed database setup.
- `examples/external-secrets.yaml` - External Secrets Operator integration.
- `examples/gateway-api.yaml` - Gateway API HTTPRoute exposure.

## Upgrade Notes

Umami 3.x includes database migrations for newer analytics features such as Boards, Shares, Session Replay, and Web Vitals.
Back up PostgreSQL before upgrading live deployments, especially when migrating from Umami 2.x.

## More Information

- [Umami documentation](https://umami.is/docs)
- [Umami environment variables](https://umami.is/docs/environment-variables)
- [HelmForge chart source](https://github.com/helmforgedev/charts/tree/main/charts/umami)
- [Configuration guide](docs/configuration.md)

### 🟢 Security Scan: `umami`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **81.818184%** |

> ✅ Security posture acceptable.

<!-- @AI-METADATA
type: chart-readme
title: Umami Helm Chart
description: README for the Umami privacy-first web analytics Helm chart

keywords: umami, analytics, privacy, web-analytics, postgresql, gateway-api, external-secrets

purpose: Chart installation, configuration, and usage documentation
scope: Chart

relations:
  - charts/umami/values.yaml
  - charts/umami/DESIGN.md
path: charts/umami/README.md
version: 2.0
date: 2026-05-07
-->
