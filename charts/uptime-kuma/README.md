<!-- SPDX-License-Identifier: Apache-2.0 -->

# Uptime Kuma Helm Chart

Deploy [Uptime Kuma](https://uptime.kuma.pet) on Kubernetes using the official
[louislam/uptime-kuma](https://hub.docker.com/r/louislam/uptime-kuma) Docker image.
Self-hosted monitoring with HTTP/TCP/DNS/Ping checks, 90+ notification services, and customizable status pages.

## Features

- **20+ monitor types** — HTTP(s), TCP, Ping, DNS, Docker, WebSocket, and more
- **90+ notification services** — Telegram, Discord, Slack, Email, Pushover, and more
- **Status pages** — public status pages with custom domains
- **SQLite or MariaDB** — embedded SQLite (default) or MySQL subchart
- **External database** — connect to existing MariaDB instances
- **Scheduled backups** — SQLite tar or mysqldump with S3 upload
- **Ingress support** — TLS with cert-manager
- **Gateway API support** — optional HTTPRoute rendering for dashboard and status pages
- **External Secrets support** — optional ExternalSecret resources for database, backup, or integration credentials
- **Dual-stack Service support** — optional `ipFamilyPolicy` and `ipFamilies`
- **Secure runtime defaults** — seccomp, dropped capabilities, read-only root filesystem, and no API token mount
- **Availability controls** — optional PodDisruptionBudget and NetworkPolicy
- **2FA** — built-in two-factor authentication

## Architecture

The chart runs one Uptime Kuma application pod behind a ClusterIP Service. The
application stores state either on the `/app/data` PVC (SQLite) or in a bundled
or external MariaDB-compatible database. Optional Ingress and HTTPRoute
resources expose the Service. A separate CronJob can archive SQLite data or run
`mysqldump`, then upload the result to S3-compatible storage.

Uptime Kuma is intentionally single-replica: horizontal scaling duplicates
monitor execution and WebSocket state. The optional PodDisruptionBudget protects
that pod from voluntary disruption but does not make the application highly
available.

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install uptime-kuma helmforge/uptime-kuma -f values.yaml
```

**OCI registry:**

```bash
helm install uptime-kuma oci://ghcr.io/helmforgedev/helm/uptime-kuma -f values.yaml
```

## Basic Example (SQLite)

```yaml
# values.yaml — default values are sufficient
# SQLite is used by default, no database configuration needed
```

After deploying, access the setup wizard:

```bash
kubectl port-forward svc/<release>-uptime-kuma 3001:80
# Open http://localhost:3001
```

## MariaDB Mode

The optional local database path uses the HelmForge MySQL subchart `2.1.1`
as a MariaDB-compatible backend.

```yaml
database:
  type: mariadb

mysql:
  enabled: true
  auth:
    password: "change-me"
```

## External Database

```yaml
database:
  type: mariadb
  external:
    host: mariadb.example.com
    name: uptime_kuma
    username: uptime_kuma
    existingSecret: uptime-kuma-db-credentials

mysql:
  enabled: false
```

## Gateway API

```yaml
gatewayAPI:
  enabled: true
  httpRoutes:
    - name: web
      parentRefs:
        - name: public
          namespace: gateway-system
      hostnames:
        - status.example.com
```

## External Secrets

Use External Secrets Operator to materialize Secrets, then point chart values at those target Secrets.

```yaml
database:
  type: mariadb
  external:
    host: mariadb.example.com
    existingSecret: uptime-kuma-db

externalSecrets:
  enabled: true
  items:
    - name: database
      spec:
        secretStoreRef:
          name: platform-secrets
          kind: ClusterSecretStore
        target:
          name: uptime-kuma-db
          creationPolicy: Owner
        data:
          - secretKey: password
            remoteRef:
              key: uptime-kuma/database
              property: password
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `docker.io/louislam/uptime-kuma` | Uptime Kuma container image |
| `image.tag` | `2.5.6` | Uptime Kuma image tag |
| `uptimeKuma.port` | `3001` | Application port |
| `database.type` | `sqlite` | Database type (sqlite, mariadb) |
| `mysql.enabled` | `false` | Deploy MySQL subchart (`helmforge/mysql` `2.1.1`) |
| `persistence.enabled` | `true` | Enable persistence for /app/data |
| `persistence.size` | `2Gi` | PVC size |
| `ingress.enabled` | `false` | Enable ingress |
| `backup.enabled` | `false` | Enable S3 backups |
| `service.port` | `80` | Service port |
| `service.ipFamilyPolicy` | omitted | Optional Service IP family policy for dual-stack clusters |
| `gatewayAPI.enabled` | `false` | Enable Gateway API HTTPRoute rendering |
| `externalSecrets.enabled` | `false` | Render ExternalSecret resources |
| `serviceAccount.automountServiceAccountToken` | `false` | Mount the Kubernetes API token |
| `runtimeStorage.tmpSizeLimit` | `256Mi` | Writable `/tmp` emptyDir limit |
| `podDisruptionBudget.enabled` | `false` | Render a PodDisruptionBudget |
| `networkPolicy.enabled` | `false` | Render an explicit NetworkPolicy |
| `image.pullPolicy` | `IfNotPresent` | Container image pull policy |
| `uptimeKuma.disableFrameSameOrigin` | `false` | Allow cross-origin iframe embedding |
| `uptimeKuma.extraEnv` | `[]` | Additional application environment variables |
| `database.external.host` | `""` | External MariaDB-compatible hostname |
| `database.external.port` | `"3306"` | External database port |
| `database.external.name` | `uptime_kuma` | External database name |
| `database.external.username` | `uptime_kuma` | External database user |
| `database.external.existingSecret` | `""` | Secret containing the external database password |
| `persistence.storageClass` | `""` | PVC StorageClass; empty uses the cluster default |
| `persistence.accessModes` | `[ReadWriteOnce]` | PVC access modes |
| `persistence.existingClaim` | `""` | Existing PVC used for `/app/data` |
| `serviceAccount.create` | `false` | Create a dedicated ServiceAccount |
| `serviceAccount.name` | `""` | Existing or generated ServiceAccount name override |
| `ingress.ingressClassName` | `traefik` | Ingress controller class |
| `ingress.hosts` | `[]` | Ingress host and path rules |
| `ingress.tls` | `[]` | Ingress TLS configuration |
| `probes.startup.enabled` | `true` | Enable the startup probe |
| `probes.liveness.enabled` | `true` | Enable the liveness probe |
| `probes.readiness.enabled` | `true` | Enable the readiness probe |
| `resources` | `{}` | Application CPU and memory requests/limits |
| `podSecurityContext` | RuntimeDefault seccomp | Pod-level security context |
| `securityContext` | Restricted defaults | Application container security context |
| `terminationGracePeriodSeconds` | `30` | Graceful termination window |
| `nodeSelector` | `{}` | Pod node selector |
| `tolerations` | `[]` | Pod tolerations |
| `affinity` | `{}` | Pod affinity and anti-affinity rules |
| `topologySpreadConstraints` | `[]` | Pod topology spread constraints |
| `backup.schedule` | `0 2 * * *` | Backup CronJob schedule |
| `backup.concurrencyPolicy` | `Forbid` | Concurrent backup execution policy |
| `backup.tmpSizeLimit` | `64Mi` | Backup temporary-storage limit |
| `backup.s3.endpoint` | `""` | Required S3-compatible endpoint when backup is enabled |
| `backup.s3.bucket` | `""` | Required backup bucket |
| `backup.s3.existingSecret` | `""` | Secret containing S3 credentials |
| `podDisruptionBudget.minAvailable` | `1` | Minimum available pod during voluntary disruptions |
| `podDisruptionBudget.maxUnavailable` | `null` | Alternative maximum unavailable value |
| `networkPolicy.ingress` | `[]` | Complete ingress rules; empty denies ingress |
| `networkPolicy.egress` | `[]` | Complete egress rules; empty denies egress |
| `gatewayAPI.httpRoutes` | `[]` | HTTPRoute definitions |
| `externalSecrets.items` | `[]` | ExternalSecret resources with complete specs |
| `extraVolumes` | `[]` | Additional application volumes |
| `extraVolumeMounts` | `[]` | Additional application volume mounts |
| `extraManifests` | `[]` | Additional Kubernetes manifests |

## Security and Operations

The application and backup containers deny privilege escalation, drop all Linux
capabilities, use the runtime-default seccomp profile, and keep the image root
filesystem read-only. Writable temporary files use bounded `emptyDir` volumes.
Kubernetes API tokens are not mounted unless explicitly enabled. Database value
changes update the pod checksum annotation so credential rotations trigger a
rollout.

The upstream standard image still starts as UID 0, so the chart does not claim a
non-root runtime. Use admission policy, network isolation, resource limits, and
tested backups as complementary controls. When enabling `networkPolicy`, define
the ingress and egress rules required for your ingress controller, DNS, monitor
targets, notification endpoints, database, and S3 service.

## Troubleshooting

- Pod startup failures: inspect all container logs and verify `/app/data` is
  writable, the PVC is bound, and the selected database is reachable.
- MariaDB failures: confirm `database.type=mariadb`, provide either the bundled
  MySQL password or an external database Secret, and check the `wait-for-db`
  init container.
- Backup failures: inspect the backup Job, verify S3 endpoint/bucket credentials,
  and confirm persistence remains enabled for SQLite backups.
- NetworkPolicy failures: start from the required DNS, database, S3, notification,
  monitor-target, and ingress-controller flows; empty rule lists deny that
  direction.
- Upgrade failures: restore the last tested backup in a non-production namespace
  before retrying the upgrade.

## Upgrade Notes

Uptime Kuma `2.5.6` fixes average-response badge calculations and updates
security-sensitive dependencies. The default `database.type=sqlite`, port, and
persistence paths are unchanged. See the
[upstream release notes](https://github.com/louislam/uptime-kuma/releases/tag/2.5.6).
Keep persistence enabled and back up `/app/data` before upgrading live
instances.

## More Information

- [Database configuration](docs/database.md)
- [Backup configuration](docs/backup.md)
- [Chart design](DESIGN.md)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/uptime-kuma)

### Security Scan: `uptime-kuma`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **72.72727%** |

Security posture acceptable.

<!-- @AI-METADATA
@description: README for the Uptime Kuma Helm chart
@type: chart-readme
@chart: uptime-kuma
@path: charts/uptime-kuma/README.md
@date: 2026-03-23
@relations:
  - charts/uptime-kuma/values.yaml
  - charts/uptime-kuma/DESIGN.md
  - charts/uptime-kuma/docs/database.md
  - charts/uptime-kuma/docs/backup.md
-->
