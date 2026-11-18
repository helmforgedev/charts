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
    parameters: pgbouncer=true
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

`database.external.parameters` appends a query string to the generated URL without exposing credentials in values.
For example, `pgbouncer=true` supports Prisma deployments that require PgBouncer compatibility mode. Do not include the
leading `?`.

When the structured fields are insufficient, store a complete URL in the same Secret and set
`database.external.existingSecretUrlKey`:

```bash
kubectl create secret generic umami-db \
  --from-literal=database-url='postgresql://umami:replace-me@pgbouncer.database.svc:6432/umami?pgbouncer=true' \
  --from-literal=password='replace-me'
```

```yaml
database:
  external:
    host: pgbouncer.database.svc
    port: 6432
    existingSecret: umami-db
    existingSecretUrlKey: database-url
```

The structured host, port, and database fields remain the source for the readiness check, optional database preparation,
and backup jobs; keep them aligned with the complete URL. When backups are enabled, the Secret must also contain the
key selected by `database.external.existingSecretPasswordKey`, or configure a separate
`backup.database.existingSecret` and `backup.database.existingSecretPasswordKey`. A complete URL and `parameters` cannot
be configured together.

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

On EKS, prefer Pod Identity or IRSA with the dedicated backup ServiceAccount. Both modes use this base configuration:

```yaml
backup:
  enabled: true
  s3:
    endpoint: https://s3.us-east-1.amazonaws.com
    bucket: umami-backups
    region: us-east-1
    credentialsFromPodIdentity: true
```

For EKS Pod Identity, install the
[EKS Pod Identity Agent](https://docs.aws.amazon.com/eks/latest/userguide/pod-id-agent-setup.html) once per cluster
unless EKS Auto Mode already provides it. Then associate the IAM role with the exact namespace and backup
ServiceAccount. The default ServiceAccount name is `<release>-umami-backup`; Pod Identity does not use a ServiceAccount
annotation.

```bash
aws eks create-addon \
  --cluster-name <cluster-name> \
  --addon-name eks-pod-identity-agent

aws eks create-pod-identity-association \
  --cluster-name <cluster-name> \
  --namespace <release-namespace> \
  --service-account <release>-umami-backup \
  --role-arn <iam-role-arn>
```

For IRSA, add its role annotation instead:

```yaml
backup:
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/umami-backup
```

Workload identity mode renders no static S3 credential Secret or credential environment variables. The identity needs
`s3:PutObject` for the configured prefix and, when enabled, `s3:CreateBucket`; leave
`backup.s3.createBucketIfNotExists=false` for object-only least privilege. IRSA additionally needs
`sts:AssumeRoleWithWebIdentity`. Allow DNS and HTTPS egress to S3 and STS. If the CNI filters link-local traffic, allow
the EKS Pod Identity or IRSA metadata endpoint for the cluster's IPv4 or IPv6 mode. Token automount is controlled by
`backup.serviceAccount.automountServiceAccountToken` and remains disabled by default.

For production, test restore procedures outside Helm. Backups without restore validation are only partial protection.

## Key Values

| Key | Default | Description |
| --- | --- | --- |
| `commonAnnotations` | `{}` | Annotations applied to every chart-owned Kubernetes resource. |
| `replicaCount` | `1` | Number of Umami pods. |
| `image.repository` | `ghcr.io/umami-software/umami` | Umami image repository. |
| `image.tag` | `3.4.0` | Umami image tag. |
| `service.type` | `ClusterIP` | Kubernetes service type. |
| `service.ipFamilyPolicy` | `""` | Optional service IP family policy. |
| `service.ipFamilies` | `[]` | Optional service IP families. |
| `ingress.enabled` | `false` | Enable Ingress. |
| `gatewayAPI.enabled` | `false` | Enable Gateway API HTTPRoute. |
| `postgresql.enabled` | `true` | Deploy bundled HelmForge PostgreSQL. |
| `database.external.host` | `""` | External PostgreSQL host when bundled PostgreSQL is disabled. |
| `database.external.parameters` | `""` | Query string appended to the generated `DATABASE_URL`, without `?`. |
| `database.external.existingSecretUrlKey` | `""` | Key in the existing Secret containing a complete `DATABASE_URL`. |
| `database.external.init.enabled` | `false` | Run optional external database preparation SQL before Umami starts. |
| `backup.s3.credentialsFromPodIdentity` | `false` | Use EKS Pod Identity or IRSA instead of static S3 credentials. |
| `backup.serviceAccount.*` | dedicated | Configure the dedicated workload identity ServiceAccount. |
| `backup.securityContext` | no escalation, drop `ALL` | Security context for the PostgreSQL and S3 uploader backup containers. |
| `externalSecrets.enabled` | `false` | Render ExternalSecret resources. |
| `networkPolicy.enabled` | `false` | Render NetworkPolicy. |
| `pdb.enabled` | `false` | Render PodDisruptionBudget. |
| `backup.enabled` | `false` | Enable S3-compatible backup CronJob. |
| `serviceAccount.automountServiceAccountToken` | `false` | Control service account token mounting. |
| `podSecurityContext` | uid 1001, `runAsNonRoot`, `RuntimeDefault` seccomp | Pod security context. |
| `securityContext` | no escalation, drop `ALL` | Security context for Umami and the chart init containers; `extraInitContainers` are rendered as provided. |
| `initContainers.waitForDatabase.enabled` | `true` | Wait for the database socket before starting Umami. |
| `initContainers.waitForDatabase.image` | `docker.io/library/busybox:1.37` | Image used by the database readiness check. |
| `initContainers.waitForDatabase.pullPolicy` | `IfNotPresent` | Pull policy for the database readiness image. |
| `extraInitContainers` | `[]` | Additional init containers for preparing shared volumes before Umami starts. |
| `extraVolumes` / `extraVolumeMounts` | `[]` | Additional pod volumes and Umami container mounts, such as GeoIP databases or custom assets. |

## Examples

- `examples/production.yaml` - production-oriented values with external PostgreSQL, Gateway API, NetworkPolicy, and PDB.
- `examples/external-postgresql.yaml` - managed database setup.
- `examples/external-secrets.yaml` - External Secrets Operator integration.
- `examples/gateway-api.yaml` - Gateway API HTTPRoute exposure.

## Security

- Pods run as the image user `nextjs` (uid 1001) with `runAsNonRoot`, no
  privilege escalation, every capability dropped, `RuntimeDefault` seccomp,
  and no ServiceAccount token.
- The first migration creates `admin` with the upstream password `umami`.
  Change it right after the first login and keep the instance private until
  then.
- Secrets accept existing Secrets or External Secrets Operator resources.

## Upgrade Notes

Umami 3.x includes database migrations for newer analytics features such as Boards, Shares, Session Replay, and Web Vitals.
Back up PostgreSQL before upgrading live deployments, especially when migrating from Umami 2.x.
Umami 3.4.0 adds annotations, API keys and opt-in MCP support, includes schema
migrations for annotations and API keys, and strengthens authenticated sessions.
Umami 3.3.1 added a username-normalization migration and fixed two-factor authentication configuration, tracking session
drift, event filtering and pagination, funnel metrics, and zero/false value responses.

## More Information

- [Umami documentation](https://umami.is/docs)
- [Umami environment variables](https://umami.is/docs/environment-variables)
- [HelmForge chart source](https://github.com/helmforgedev/charts/tree/main/charts/umami)
- [Configuration guide](docs/configuration.md)

### Security Scan: `umami`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **89.393936%** |

> Security posture acceptable.

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
