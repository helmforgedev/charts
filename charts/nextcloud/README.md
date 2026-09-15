# Nextcloud

[Nextcloud](https://nextcloud.com/) provides self-hosted file synchronization,
sharing and collaboration. This chart uses the official Apache image with
PostgreSQL, Redis, managed background jobs and coordinated S3 backups.

## Requirements

- Kubernetes 1.29 or newer and Helm 3 or newer.
- Persistent storage supporting UID/GID 33 and fsGroup ownership.
- Public DNS and a TLS-enabled ingress or Gateway controller for external access.
- An existing private S3-compatible bucket and credential Secret for backups.
- External Secrets Operator only when that integration is enabled.

The application defaults to `nextcloud:34.0.4-apache`, with verified amd64 and
arm64 support. The chart is Apache-2.0 licensed; Nextcloud Server is AGPL-3.0.
One replica and Recreate updates provide an explicit single-writer operating
model. Backups and upgrades have scheduled downtime.

## Installation

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install nextcloud helmforge/nextcloud \
  --namespace nextcloud --create-namespace
```

Alternatively, use OCI:

```bash
helm install nextcloud oci://ghcr.io/helmforgedev/helm/nextcloud \
  --namespace nextcloud --create-namespace
```

Wait for initial installation to complete, then forward the local service:

```bash
kubectl -n nextcloud port-forward service/nextcloud 8080:80
```

Open `http://localhost:8080`. The default administrator login is `admin`. Retrieve
the `admin-password` key from Secret `nextcloud-auth` using your approved Secret
workflow. Prefer `nextcloud.existingSecret` for managed production credentials.
The bootstrap password does not reset existing account passwords.

## Features

- Official application image and official HelmForge PostgreSQL/Redis dependencies.
- Automated native installation and guarded sequential application upgrades.
- Persistent native configuration, instance identity, custom apps, themes and data.
- Non-root Apache, read-only root filesystem, dropped capabilities and seccomp.
- Co-located cron coordinated with the native initialization lock.
- Existing Secret and External Secrets Operator contracts.
- Explicit trusted hosts/proxies, SMTP, Ingress, Gateway API and dualstack Service.
- Coordinated SQL/files backup, checksummed S3 publication and fresh-storage restore.
- Real HTTP/WebDAV acceptance tests and a full backup/recovery scenario.

## Production configuration

Start with [examples/production.yaml](examples/production.yaml). Supply the actual
public hostname, proxy CIDRs, TLS Secret, storage sizes and credential Secrets.
Configure ingress upload limits and timeouts alongside the PHP limits. Verify
email delivery before relying on password recovery or sharing notifications.

Helm uninstall deletes the chart-created application PVC. Use
`persistence.existingClaim` when the volume lifecycle is managed independently,
and retain tested backups before removing a release or namespace.

PostgreSQL and Redis are enabled by default. To use managed private endpoints,
disable the corresponding subchart and provide `externalDatabase` or
`externalRedis` settings. These external services must already exist. The chart
supports PostgreSQL and standalone Redis; it does not perform database-engine
conversion or configure Redis Sentinel/Cluster discovery.

## Optional integrations

Enable `imaginary.enabled` for private image-preview offloading and
`notifyPush.enabled` for the official Client Push daemon. Both are opt-in, run
in the application Pod and use official pinned images. Client Push uses the
existing HTTPS endpoint at `/push` and requires a compatible operator-installed
Nextcloud app plus the upstream setup test.

See [setup, verification and lifecycle instructions](docs/integrations.md) before enabling them.

## Backup and restore

Integrated backups stop the application and cron, capture PostgreSQL and the
complete PVC, resume service, and publish checksummed objects with a final
completion marker. A failed snapshot retains a volume lock for explicit recovery.
Restore requires a completed backup, matching application version, original
administrator credentials, fresh PVC and empty database.

See [backup and restore](docs/backup-restore.md) before enabling the schedule.
Retain external Secrets separately. Practice restoration and verify non-admin
login, file contents/identities, shares, settings and new writes.

## Examples and operational guides

- [Local installation](examples/simple.yaml)
- [Production routing and backups](examples/production.yaml)
- [Gateway API](examples/gateway-api.yaml)
- [External database and Redis](examples/external-services.yaml)
- [Configuration and exposure](docs/configuration.md)
- [Backup, failure recovery and restore](docs/backup-restore.md)
- [Upgrades and migration from another chart](docs/upgrades.md)
- [Architecture and tradeoffs](DESIGN.md)

## Non-goals

This chart does not provision office suites, Talk media relays, full-text search,
horizontal Nextcloud scaling or primary S3 file storage. Its S3 integration is
backup storage. Custom Nextcloud apps are operator-managed and must support the
selected upstream release. Helm rollback cannot reverse database migrations.

## Security Scan: `nextcloud`

| Framework | Score |
| --- | --- |
| MITRE + NSA + SOC2 | **89.6104%** |

> Security posture acceptable.

Measured locally on 2026-09-15 with Kubescape 4.0.14 against the default rendered
application and bundled dependencies. The application uses a read-only root
filesystem; the PostgreSQL/Redis subcharts retain their upstream filesystem
defaults. This configuration assessment does not replace image CVE scanning.

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Parameters

<!-- BEGIN GENERATED VALUES -->

| Parameter | Description | Default |
| --- | --- | --- |
| `nameOverride` | Override the chart name. | `""` |
| `fullnameOverride` | Override the release resource name. | `""` |
| `commonLabels` | Extra labels on resources. | `{}` |
| `image.repository` | Official image repository. | `"docker.io/library/nextcloud"` |
| `image.tag` | Pinned application release. | `"34.0.4-apache"` |
| `image.pullPolicy` | Image pull policy. | `"IfNotPresent"` |
| `imagePullSecrets` | Registry authentication Secret references. | `[]` |
| `nextcloud.adminUser` | Initial administrator login; changing this does not rename existing users. | `"admin"` |
| `nextcloud.adminPassword` | Initial administrator password; generated and retained when empty. | `""` |
| `nextcloud.existingSecret` | Existing Secret containing the initial administrator password. | `""` |
| `nextcloud.existingSecretPasswordKey` | Password key in the administrator Secret. | `"admin-password"` |
| `nextcloud.trustedDomains` | Allowed HTTP Host names, reconciled on upgrades. | `["localhost"]` |
| `nextcloud.trustedProxies` | Explicit reverse proxy IP addresses or CIDRs. | `[]` |
| `nextcloud.overwriteCliUrl` | Public URL for links generated by background jobs. | `"http://localhost:8080"` |
| `nextcloud.overwriteProtocol` | Proxy protocol override; empty, http or https. | `""` |
| `nextcloud.overwriteHost` | Public host override behind a trusted proxy. | `""` |
| `nextcloud.defaultPhoneRegion` | Default phone region for profile validation. | `"US"` |
| `nextcloud.maintenanceWindowStart` | Start hour in UTC for expensive maintenance background tasks. | `1` |
| `php.memoryLimit` | Maximum memory per PHP request. | `"512M"` |
| `php.uploadLimit` | Maximum upload and POST body size. | `"512M"` |
| `imaginary.enabled` | Enable private preview offloading. | `false` |
| `imaginary.image.repository` | Official Nextcloud Imaginary image. | `"ghcr.io/nextcloud-releases/aio-imaginary"` |
| `imaginary.image.digest` | Immutable multi-platform image digest. | `"sha256:ea96034f97e9921015001c43947ab88ee5516e7e793c4c753a3618feca9e8548"` |
| `imaginary.image.pullPolicy` | Image pull policy. | `"IfNotPresent"` |
| `imaginary.maxAllowedResolution` | Maximum source resolution in megapixels. | `50` |
| `imaginary.previewProviders` | Preview providers when enabled. | `["OC\\Preview\\TXT","OC\\Preview\\MarkDown","OC\\Preview\\OpenDocument","OC\\Preview\\Krita","OC\\Preview\\Imaginary"]` |
| `imaginary.resources.requests.cpu` | CPU request. | `"25m"` |
| `imaginary.resources.requests.memory` | Memory request. | `"128Mi"` |
| `imaginary.resources.limits.cpu` | CPU limit. | `"1"` |
| `imaginary.resources.limits.memory` | Memory limit. | `"512Mi"` |
| `notifyPush.enabled` | Enable the daemon; install and configure the Client Push app separately. | `false` |
| `notifyPush.image.repository` | Official Client Push daemon image. | `"ghcr.io/nextcloud/notify_push"` |
| `notifyPush.image.tag` | Pinned daemon version. | `"v1.4.1"` |
| `notifyPush.image.pullPolicy` | Image pull policy. | `"IfNotPresent"` |
| `notifyPush.resources.requests.cpu` | CPU request. | `"10m"` |
| `notifyPush.resources.requests.memory` | Memory request. | `"32Mi"` |
| `notifyPush.resources.limits.cpu` | CPU limit. | `"500m"` |
| `notifyPush.resources.limits.memory` | Memory limit. | `"128Mi"` |
| `cron.enabled` | Enable Nextcloud cron processing. | `true` |
| `cron.interval` | Seconds between invocations; upstream recommends five minutes. | `300` |
| `cron.initialDelay` | Delay the first cron invocation after Pod startup, matching upstream timer guidance. | `300` |
| `cron.resources.requests.cpu` | requests cpu | `"25m"` |
| `cron.resources.requests.memory` | requests memory | `"128Mi"` |
| `cron.resources.limits.cpu` | limits cpu | `"500m"` |
| `cron.resources.limits.memory` | limits memory | `"512Mi"` |
| `resources.requests.cpu` | requests cpu | `"100m"` |
| `resources.requests.memory` | requests memory | `"512Mi"` |
| `resources.limits.cpu` | limits cpu | `"2"` |
| `resources.limits.memory` | limits memory | `"1536Mi"` |
| `initResources.requests.cpu` | requests cpu | `"25m"` |
| `initResources.requests.memory` | requests memory | `"64Mi"` |
| `initResources.limits.cpu` | limits cpu | `"500m"` |
| `initResources.limits.memory` | limits memory | `"128Mi"` |
| `podSecurityContext.runAsNonRoot` | podSecurityContext runAsNonRoot | `true` |
| `podSecurityContext.runAsUser` | podSecurityContext runAsUser | `33` |
| `podSecurityContext.runAsGroup` | podSecurityContext runAsGroup | `33` |
| `podSecurityContext.fsGroup` | podSecurityContext fsGroup | `33` |
| `podSecurityContext.fsGroupChangePolicy` | podSecurityContext fsGroupChangePolicy | `"OnRootMismatch"` |
| `podSecurityContext.seccompProfile.type` | seccompProfile type | `"RuntimeDefault"` |
| `securityContext.allowPrivilegeEscalation` | securityContext allowPrivilegeEscalation | `false` |
| `securityContext.readOnlyRootFilesystem` | securityContext readOnlyRootFilesystem | `true` |
| `securityContext.capabilities.drop` | capabilities drop | `["ALL"]` |
| `persistence.enabled` | Enable the complete /var/www/html PVC. | `true` |
| `persistence.existingClaim` | Reuse a PVC, including a restored instance. | `""` |
| `persistence.storageClass` | Storage class; empty uses the cluster default. | `""` |
| `persistence.accessModes` | Access modes for the single application writer. | `["ReadWriteOnce"]` |
| `persistence.size` | Requested volume size. | `"10Gi"` |
| `service.type` | Kubernetes Service type. | `"ClusterIP"` |
| `service.port` | Service port mapped to Apache 8080. | `80` |
| `service.ipFamilyPolicy` | Optional IP family policy. | `""` |
| `service.ipFamilies` | Optional IP family order. | `[]` |
| `postgresql.enabled` | Enable the bundled database. | `true` |
| `postgresql.auth.database` | auth database | `"nextcloud"` |
| `postgresql.auth.username` | auth username | `"nextcloud"` |
| `externalDatabase.host` | PostgreSQL DNS name. | `""` |
| `externalDatabase.port` | PostgreSQL port. | `5432` |
| `externalDatabase.database` | Existing empty database on first installation. | `"nextcloud"` |
| `externalDatabase.username` | Database owner login. | `"nextcloud"` |
| `externalDatabase.existingSecret` | Secret containing the database password. | `""` |
| `externalDatabase.existingSecretPasswordKey` | Database password key. | `"password"` |
| `redis.enabled` | Enable bundled standalone Redis. | `true` |
| `redis.architecture` | Supported topology. | `"standalone"` |
| `externalRedis.host` | Standalone Redis DNS name. | `""` |
| `externalRedis.port` | Redis port. | `6379` |
| `externalRedis.existingSecret` | Secret containing the Redis password. | `""` |
| `externalRedis.existingSecretPasswordKey` | Redis password key. | `"password"` |
| `podLabels` | Pod labels. | `{}` |
| `podAnnotations` | Pod annotations. | `{}` |
| `nodeSelector` | Node scheduling constraints. | `{}` |
| `tolerations` | Tolerations. | `[]` |
| `affinity` | Pod affinity configuration. | `{}` |
| `terminationGracePeriodSeconds` | Grace period for draining HTTP requests and active background jobs. | `120` |
| `ingress.enabled` | Render an Ingress. | `false` |
| `ingress.ingressClassName` | Ingress controller class. | `""` |
| `ingress.annotations` | Controller-specific annotations, including request body size limits. | `{}` |
| `ingress.hosts` | Host/path rules. | `[{"host":"nextcloud.example.com","paths":[{"path":"/","pathType":"Prefix"}]}]` |
| `ingress.tls` | TLS Secret references and hosts. | `[]` |
| `gatewayAPI.enabled` | Render HTTPRoute resources. | `false` |
| `gatewayAPI.httpRoutes` | Complete route definitions; missing backends target Nextcloud. | `[]` |
| `externalSecrets.enabled` | Render ExternalSecret resources. | `false` |
| `externalSecrets.refreshInterval` | Default refresh interval. | `"1h"` |
| `externalSecrets.items` | Complete ExternalSecret definitions with provider spec. | `[]` |
| `smtp.enabled` | Enable SMTP configuration. | `false` |
| `smtp.host` | SMTP server hostname. | `""` |
| `smtp.port` | SMTP port. | `587` |
| `smtp.secure` | Transport security: tls for STARTTLS, ssl for implicit TLS, or empty. | `"tls"` |
| `smtp.fromAddress` | Sender local part. | `"nextcloud"` |
| `smtp.domain` | Sender domain. | `"example.com"` |
| `smtp.username` | Authentication login; empty disables SMTP authentication. | `""` |
| `smtp.existingSecret` | Existing SMTP credential Secret. | `""` |
| `smtp.existingSecretPasswordKey` | SMTP password key. | `"password"` |
| `networkPolicy.enabled` | Enable NetworkPolicy. | `false` |
| `networkPolicy.extraIngress` | Additional inbound rules; default allows same-namespace clients. | `[]` |
| `networkPolicy.extraEgress` | Additional outbound rules for external databases, SMTP and Internet integrations. | `[]` |
| `backup.enabled` | Enable scheduled integrated backups. | `false` |
| `backup.schedule` | Cron schedule. | `"0 2 * * *"` |
| `backup.suspend` | Suspend scheduling, retaining manual job support. | `false` |
| `backup.activeDeadlineSeconds` | Maximum total job duration in seconds. | `7200` |
| `backup.quiesceTimeout` | Maximum time to wait for web and cron termination. | `180` |
| `backup.successfulJobsHistoryLimit` | Successful job history. | `1` |
| `backup.failedJobsHistoryLimit` | Failed jobs retained for diagnostics. | `3` |
| `backup.databaseImage` | Official SQL client; must match the PostgreSQL server major. | `"docker.io/library/postgres:18.6-trixie"` |
| `backup.s3Image` | Official AWS CLI for S3-compatible object stores. | `"public.ecr.aws/aws-cli/aws-cli:2.36.43"` |
| `backup.workspaceSize` | Maximum ephemeral staging storage; allow space for the complete archive and dump. | `"20Gi"` |
| `backup.resources.requests.cpu` | requests cpu | `"100m"` |
| `backup.resources.requests.memory` | requests memory | `"256Mi"` |
| `backup.resources.limits.cpu` | limits cpu | `"2"` |
| `backup.resources.limits.memory` | limits memory | `"1Gi"` |
| `backup.s3.endpoint` | Optional endpoint URL for S3-compatible storage. | `""` |
| `backup.s3.allowInsecureHTTP` | Explicitly permit HTTP only on a trusted isolated network; use HTTPS in production. | `false` |
| `backup.s3.bucket` | Existing private bucket. | `""` |
| `backup.s3.prefix` | Backup object prefix, without leading or trailing slash. | `"nextcloud"` |
| `backup.s3.region` | AWS signing region. | `"us-east-1"` |
| `backup.s3.existingSecret` | Secret containing S3 credentials. | `""` |
| `backup.s3.existingSecretAccessKeyKey` | Access key ID key. | `"access-key"` |
| `backup.s3.existingSecretSecretKeyKey` | Secret access key key. | `"secret-key"` |
| `restore.enabled` | Keep application stopped and create a restore Job. Disable after successful restore. | `false` |
| `restore.backupPath` | Exact S3 prefix for a completed backup, including its unique backup ID. | `""` |

<!-- END GENERATED VALUES -->
