# Moodle

Production-oriented [Moodle](https://moodle.org) LMS deployment with official
upstream artifacts, PostgreSQL/MySQL/MariaDB, protected bootstrap, read-only application code,
scheduled task processing and explicit maintenance operations.

The chart targets Moodle **5.2.2** and PHP **8.4.25** through a digest-pinned
MoodleHQ PHP/Apache image. The application archive is independently SHA-256
verified before extraction. MoodleHQ's image supplies the runtime, not the LMS.

## Features

- Read-only Moodle code, non-root Apache on port 8080, dropped capabilities.
- PostgreSQL, MySQL or MariaDB: external servers or selectable HelmForge subcharts.
- Verified database TLS, custom connection ports and existing credential Secrets.
- Serialized first installation using upstream CLI and database advisory locks.
- Explicit maintenance Job; normal startup refuses automatic schema migrations.
- Independent cron and optional ad-hoc task containers sharing code and data.
- Redis sessions with optional TLS; documented separation from MUC cache mapping.
- Persistent Moodledata and fail-fast shared-storage requirements for scaling.
- Ingress, Gateway API, dual-stack Services, NetworkPolicy, HPA and PDB.
- Existing Secrets, canonical External Secrets integration and SMTP configuration.
- Authenticated Moodle metrics, isolated listener, ServiceMonitor and alert rules.
- Complete backup/restore, upgrade, immutable plugin and Bitnami migration guides.

## Install

OCI installation:

```bash
helm install moodle oci://ghcr.io/helmforgedev/helm/moodle \
  --namespace learning --create-namespace
```

HTTPS repository installation:

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update helmforge
helm install moodle helmforge/moodle --namespace learning --create-namespace
```

The CI release pipeline owns the published chart version.

## Quick start

```bash
kubectl -n learning rollout status deployment/moodle --timeout=5m
kubectl -n learning port-forward service/moodle 8080:80
```

Open <http://localhost:8080>. The upstream installer already initialized the
database. Retrieve the generated administrator password in a private terminal:

```bash
kubectl -n learning get secret moodle-admin \
  -o jsonpath='{.data.admin-password}' | base64 --decode
```

The username defaults to admin. Use an existing Secret for production and
configure the real public HTTPS URL before directing students to the site.
Changing a bootstrap password does not reset an existing Moodle account.

## Prerequisites

- Kubernetes 1.26 or newer and Helm with OCI support.
- Dynamic PVC provisioning or an existing data claim writable by UID/GID 33.
- Outbound HTTPS for archive mode, or a compatible immutable application image.
- PostgreSQL 16+, MySQL 8.4+ or MariaDB 10.11+; PostgreSQL is enabled by default.
- A real RWX backend and Redis sessions before enabling multiple web replicas.
- Gateway API or External Secrets controllers only when those integrations are enabled.

## Production example

```yaml
moodle:
  wwwroot: https://learn.example.com
  sslProxy: true
  existingSecret: learning-admin
  adminEmail: learning-admin@example.com
persistence:
  size: 50Gi
sessions:
  enabled: true
redis:
  enabled: true
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: learn.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: learning-tls
      hosts: [learn.example.com]
```

Create the referenced admin/TLS Secrets beforehand. This example provides one
web replica; it does not claim HA for standalone databases or Redis.

## Deployment scenarios

Use the examples directory for disposable development, staging, production,
External Secrets and shared-storage deployments. Each scenario is explicit:
the chart does not silently select database/storage capacity from a preset.
Keep production database and Redis failover under your infrastructure's tested
operating procedures.

## Security Scan: moodle

| Framework | Score |
| --- | --- |
| MITRE + NSA + SOC2 | **93.63636%** |

Security posture acceptable. Local Kubescape 4.0.13 scan of the default render
on 2026-09-09, using the same frameworks as CI. Findings include opt-in
NetworkPolicy and the bundled database's writable filesystem. The scanner also
flags the existing metrics smoke script's literal Bearer authorization header
as a misplaced secret; actual tokens are read from Secrets at runtime. This is
a Kubernetes configuration assessment, not an image vulnerability scan.

## Operational guides

- [operations](docs/operations.md)
- [production](docs/production.md)
- [backup-restore](docs/backup-restore.md)
- [troubleshooting](docs/troubleshooting.md)
- [observability](docs/observability.md)

## Complete values reference

Bundled PostgreSQL, MySQL, MariaDB and Redis also accept their full HelmForge subchart values.
Their schemas validate additional subchart settings; the tables below document
every value explicitly set or exposed by the Moodle parent chart.

### nameOverride

Override the chart name.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `nameOverride` | `""` | Override the chart name. |

### fullnameOverride

Override resource names.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `fullnameOverride` | `""` | Override resource names. |

### commonLabels

Additional resource labels; selector labels are reserved.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `commonLabels` | `{}` | Additional resource labels; selector labels are reserved. |

### replicaCount

Number of web pods; multiple replicas require RWX and Redis sessions.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `replicaCount` | `1` | Number of web pods; multiple replicas require RWX and Redis sessions. |

### image

Official PHP/Apache runtime, separately pinned from the Moodle code.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `image.repository` | `docker.io/moodlehq/moodle-php-apache` | Image repository; custom images must contain the same PHP/Apache tools. |
| `image.tag` | `8.4-bookworm` | Human-readable PHP variant; digest pins the actual bytes. |
| `image.digest` | `sha256:922af51668352004b4255cdc1f726a63f0cee7c1354eaf66dd8d5f2c7cc379b5` | Multi-architecture manifest digest. |
| `image.pullPolicy` | `IfNotPresent` | Container image pull policy. |

### imagePullSecrets

Registry credentials.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `imagePullSecrets` | `[]` | Registry credentials. |

### source

Immutable Moodle code distribution, prepared once per pod.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `source.mode` | `archive` | archive downloads a verified release; image copies code baked into image.path. |
| `source.url` | `https://download.moodle.org/download.php/direct/stable502/moodle-5.2.2.tgz` | Official release archive or an HTTPS mirror of identical bytes. |
| `source.sha256` | `72be209e7c0f5341b87de0bc993b2430087fda2769d8c3cc2f32736d1513e88c` | SHA-256 of the archive; verified before extraction. |
| `source.imagePath` | `/opt/moodle` | Source directory in a custom image when mode=image. |
| `source.downloadTimeout` | `180` | Maximum HTTPS download time per attempt in seconds. |

### moodle

Moodle application settings.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `moodle.wwwroot` | `http://localhost:8080` | Public URL without trailing slash. Set the real HTTPS URL in production. |
| `moodle.siteName` | `Moodle Learning Platform` | Full site name used only on first installation. |
| `moodle.shortName` | `Moodle` | Short site name used only on first installation. |
| `moodle.language` | `en` | Installation language. Non-English language packs require upstream egress. |
| `moodle.adminUser` | `admin` | Administrative account name used only on first installation. |
| `moodle.adminEmail` | `admin@example.com` | Administrative contact email. |
| `moodle.adminPassword` | `""` | Inline bootstrap password; generated and preserved when empty. |
| `moodle.existingSecret` | `""` | Existing bootstrap secret. Password changes do not reset an installed account. |
| `moodle.existingSecretPasswordKey` | `admin-password` | Bootstrap secret password key. |
| `moodle.autoInstall` | `true` | Enable automated first installation into an empty application database. |
| `moodle.sslProxy` | `false` | Allow TLS termination at a trusted proxy; pair with HTTPS wwwroot. |
| `moodle.reverseProxy` | `false` | Enable only when proxy rewrites Host; ordinary Ingress preserves Host. |
| `moodle.disableUpdateAutodeploy` | `true` | Disable browser-based plugin installation and code updates. |
| `moodle.noEmailEver` | `false` | Disable outgoing email, useful in restored or staging environments. |
| `moodle.timezone` | `UTC` | Site timezone, configured consistently for PHP and Moodle. |
| `moodle.extraConfig` | `""` | Additional config.php statements before Moodle setup; trusted administrator code. |
| `moodle.extraEnv` | `[]` | Extra environment variables for PHP workloads, including cron. |
| `moodle.extraEnvFrom` | `[]` | Extra environment sources for PHP workloads. |

### database

Application database connection; disable every database subchart for an external server.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `database.type` | `postgresql` | Backend: postgresql, mysql or mariadb. Changing an installed site's backend requires a separate data migration. |
| `database.host` | `""` | External database hostname; ignored when the selected subchart is enabled. |
| `database.port` | `0` | External database port; zero selects 5432 for PostgreSQL or 3306 for MySQL/MariaDB. |
| `database.name` | `moodle` | External database name. |
| `database.username` | `moodle` | External database user. |
| `database.existingSecret` | `""` | External database password Secret, required when all database subcharts are disabled. |
| `database.existingSecretPasswordKey` | `password` | Password key in the external Secret. |
| `database.prefix` | `mdl_` | Moodle table prefix; at most ten alphanumeric/underscore characters. |
| `database.sslMode` | `prefer` | PostgreSQL libpq SSL mode; use verify-full with a CA for external PostgreSQL. |
| `database.mysqlSslMode` | `disable` | MySQL/MariaDB TLS mode: disable, require (encryption only), or verify-full (CA and hostname). |
| `database.collation` | `utf8mb4_unicode_ci` | MySQL/MariaDB collation; Unicode utf8mb4 is required for full Moodle character support. |
| `database.tlsSecret` | `""` | Optional Secret containing the database CA certificate. |
| `database.tlsCAKey` | `ca.crt` | CA certificate key in database.tlsSecret. |
| `database.connectTimeout` | `180` | Maximum wait for authenticated DB connectivity and installer lock. |

### postgresql

Bundled HelmForge PostgreSQL; full subchart values may be overridden.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `postgresql.enabled` | `true` | Deploy PostgreSQL. |
| `postgresql.architecture` | `standalone` | Standalone or replication; external database is recommended for managed HA. |
| `postgresql.auth.database` | `moodle` | Initial database name. |
| `postgresql.auth.username` | `moodle` | Initial application user. |
| `postgresql.auth.password` | `""` | Application password; generated by the subchart when empty. |
| `postgresql.auth.existingSecret` | `""` | Existing PostgreSQL credentials Secret. |
| `postgresql.auth.existingSecretUserPasswordKey` | `user-password` | Application password key. |

### mysql

Bundled HelmForge MySQL; full subchart values may be overridden.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `mysql.enabled` | `false` | Deploy MySQL; requires database.type=mysql and the other database subcharts disabled. |
| `mysql.architecture` | `standalone` | Standalone or replication; the Moodle connection always targets the writable Service. |
| `mysql.auth.database` | `moodle` | Initial database name. |
| `mysql.auth.username` | `moodle` | Initial application user. |
| `mysql.auth.password` | `""` | Application password; generated by the subchart when empty. |
| `mysql.auth.existingSecret` | `""` | Existing MySQL credentials Secret. |
| `mysql.auth.existingSecretUserPasswordKey` | `mysql-user-password` | Application password key. |

### mariadb

Bundled HelmForge MariaDB; full subchart values may be overridden.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `mariadb.enabled` | `false` | Deploy MariaDB; requires database.type=mariadb and the other database subcharts disabled. |
| `mariadb.architecture` | `standalone` | Standalone or replication; the Moodle connection always targets the writable Service. |
| `mariadb.auth.database` | `moodle` | Initial database name. |
| `mariadb.auth.username` | `moodle` | Initial application user. |
| `mariadb.auth.password` | `""` | Application password; generated by the subchart when empty. |
| `mariadb.auth.existingSecret` | `""` | Existing MariaDB credentials Secret. |
| `mariadb.auth.existingSecretUserPasswordKey` | `mariadb-user-password` | Application password key. |

### sessions

Redis session options; independent of Moodle MUC cache mappings.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `sessions.enabled` | `false` | Use Redis sessions; requires bundled Redis or an external Redis endpoint. |
| `sessions.host` | `""` | External Redis hostname. |
| `sessions.port` | `6379` | External Redis port. |
| `sessions.database` | `0` | Redis logical database dedicated to Moodle sessions. |
| `sessions.prefix` | `moodle_session_` | Key prefix; isolate each Moodle installation. |
| `sessions.existingSecret` | `""` | External Redis password Secret; empty permits unauthenticated external Redis. |
| `sessions.existingSecretPasswordKey` | `redis-password` | Redis password key. |
| `sessions.tlsSecret` | `""` | Optional Secret containing CA for Redis TLS. |
| `sessions.tlsCAKey` | `ca.crt` | Redis CA certificate key. |
| `sessions.acquireLockTimeout` | `120` | Maximum time to acquire a session lock in seconds. |
| `sessions.lockExpire` | `7200` | Session lock expiration in seconds. |

### redis

Optional HelmForge Redis subchart for sessions.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `redis.enabled` | `false` | Deploy Redis; also set sessions.enabled=true. |
| `redis.architecture` | `standalone` | Supported bundled topology: standalone. |
| `redis.auth.enabled` | `true` | Require Redis authentication. |
| `redis.auth.password` | `""` | Inline Redis password, generated when empty. |
| `redis.auth.existingSecret` | `""` | Existing Redis credentials Secret. |
| `redis.auth.existingSecretPasswordKey` | `redis-password` | Password key. |

### persistence

Persistent Moodle data, always outside the web root.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `persistence.enabled` | `true` | Enable persistent moodledata. Disable only for disposable tests. |
| `persistence.existingClaim` | `""` | Existing data claim; accessModes must describe its real capabilities. |
| `persistence.storageClass` | `""` | Storage class; empty uses cluster default, '-' disables dynamic class selection. |
| `persistence.accessModes` | `["ReadWriteOnce"]` | Use ReadWriteMany for multiple web replicas. |
| `persistence.size` | `10Gi` | Requested data capacity. |
| `persistence.retain` | `true` | Retain chart-created data PVC when uninstalling. |
| `persistence.annotations` | `{}` | Additional PVC annotations. |

### php

PHP runtime configuration.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `php.memoryLimit` | `256M` | Memory limit for each PHP process; align with pod concurrency/resources. |
| `php.uploadMaxFilesize` | `64M` | Maximum uploaded file size. |
| `php.postMaxSize` | `64M` | Maximum POST size, at least uploadMaxFilesize. |
| `php.maxInputVars` | `5000` | Moodle requires at least 5000 form input variables. |
| `php.maxExecutionTime` | `300` | HTTP execution time limit; CLI tasks are not constrained by this value. |
| `php.extraIni` | `""` | Additional PHP INI directives. |

### apache

Apache prefork concurrency; each child may consume php.memoryLimit.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `apache.maxRequestWorkers` | `8` | Maximum concurrent PHP requests per web pod. |

### cron

Cron sidecar shares code and data with its web pod, including RWO storage.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `cron.enabled` | `true` | Run scheduled Moodle tasks; Moodle database locks coordinate multiple pods. |
| `cron.interval` | `60` | Interval between invocations; a running task is never overlapped in the same pod. |
| `cron.resources.requests.cpu` | `100m` | Kubernetes configuration; validated against the resource schema. |
| `cron.resources.requests.memory` | `256Mi` | Kubernetes configuration; validated against the resource schema. |
| `cron.resources.limits.cpu` | `1` | Kubernetes configuration; validated against the resource schema. |
| `cron.resources.limits.memory` | `1Gi` | Kubernetes configuration; validated against the resource schema. |

### adhoc

Additional ad-hoc task processing in a separate sidecar.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `adhoc.enabled` | `false` | Enable a dedicated ad-hoc worker; normal cron already handles ad-hoc tasks. |
| `adhoc.keepAlive` | `55` | Upstream keep-alive duration in seconds. |
| `adhoc.resources.requests.cpu` | `100m` | Kubernetes configuration; validated against the resource schema. |
| `adhoc.resources.requests.memory` | `256Mi` | Kubernetes configuration; validated against the resource schema. |
| `adhoc.resources.limits.cpu` | `1` | Kubernetes configuration; validated against the resource schema. |
| `adhoc.resources.limits.memory` | `1Gi` | Kubernetes configuration; validated against the resource schema. |

### maintenance

Explicit maintenance window; stops web/task pods before running an operator-requested job.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `maintenance.enabled` | `false` | Scale web pods to zero and run the selected maintenance action. |
| `maintenance.runId` | `manual-1` | Unique operation identifier. Change for each operation to create a new Job. |
| `maintenance.action` | `checks` | Upstream CLI operation: upgrade, checks, purge-caches, enable, or disable. |
| `maintenance.activeDeadlineSeconds` | `1800` | Maximum execution time; unsuccessful upgrades stay in maintenance. |

### metrics

Optional authenticated Moodle application metrics through tool_monitoring.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `metrics.enabled` | `false` | Install/configure the plugin and expose a private metrics listener. |
| `metrics.existingSecret` | `""` | Existing Secret containing the bearer token; empty generates a retained Secret. |
| `metrics.existingSecretTokenKey` | `token` | Key containing a nonempty token in the metrics Secret. |
| `metrics.plugin.mode` | `archive` | archive downloads pinned source; image requires the plugin in the application image. |
| `metrics.plugin.url` | `https://codeload.github.com/daniil-berg/moodle-tool_monitoring/tar.gz/23c45f66b6c3ed409b0749017b3387c1744016cc` | Immutable upstream tool_monitoring 1.1.0 archive. |
| `metrics.plugin.sha256` | `dc7a5256e93e10b0514fcb752767e2554b7aa0cd24e8c8d74e54c33b358028e1` | SHA-256 checked before extracting plugin code. |
| `metrics.enabledMetrics` | `["courses","overdue_tasks","quiz_attempts_in_progress","user_accounts","users_online"]` | Built-in metrics managed by Helm; custom metrics remain administrator-managed. |
| `metrics.serviceMonitor.enabled` | `false` | Create an authenticated ServiceMonitor for the private metrics Service. |
| `metrics.serviceMonitor.labels` | `{}` | Labels matching the Prometheus serviceMonitorSelector. |
| `metrics.serviceMonitor.annotations` | `{}` | Extra ServiceMonitor annotations. |
| `metrics.serviceMonitor.interval` | `60s` | Scrape interval; metrics query Moodle's database. |
| `metrics.serviceMonitor.scrapeTimeout` | `20s` | Per-scrape timeout, lower than interval. |
| `metrics.serviceMonitor.relabelings` | `[]` | Target relabeling rules. |
| `metrics.serviceMonitor.metricRelabelings` | `[]` | Metric relabeling rules; avoid summing global Moodle counts across web replicas. |
| `metrics.ingressFrom` | `[]` | Allowed metrics clients when NetworkPolicy is enabled; empty permits any client on port 9090. |
| `metrics.prometheusRule.enabled` | `false` | Create scrape availability and persistent overdue-task alerts; requires ServiceMonitor. |
| `metrics.prometheusRule.labels` | `{}` | Labels matching the Prometheus ruleSelector. |
| `metrics.prometheusRule.unavailableFor` | `5m` | How long all scrape targets must be missing or down before alerting. |
| `metrics.prometheusRule.overdueTasksFor` | `15m` | How long overdue tasks must remain present before alerting. |

### smtp

Outbound SMTP settings.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `smtp.hosts` | `""` | SMTP server hostname with optional port, for example smtp.example.com:587. |
| `smtp.security` | `tls` | Transport security: empty, tls, or ssl. |
| `smtp.username` | `""` | SMTP user. |
| `smtp.existingSecret` | `""` | Secret containing SMTP password. |
| `smtp.existingSecretPasswordKey` | `smtp-password` | SMTP password key. |
| `smtp.noReplyAddress` | `noreply@example.com` | Sender address for automated notifications. |

### resources

Web container resources.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `resources.requests.cpu` | `250m` | Kubernetes configuration; validated against the resource schema. |
| `resources.requests.memory` | `512Mi` | Kubernetes configuration; validated against the resource schema. |
| `resources.limits.cpu` | `2` | Kubernetes configuration; validated against the resource schema. |
| `resources.limits.memory` | `2Gi` | Kubernetes configuration; validated against the resource schema. |

### initResources

Source preparation and installation resources.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `initResources.requests.cpu` | `250m` | Kubernetes configuration; validated against the resource schema. |
| `initResources.requests.memory` | `256Mi` | Kubernetes configuration; validated against the resource schema. |
| `initResources.limits.cpu` | `2` | Kubernetes configuration; validated against the resource schema. |
| `initResources.limits.memory` | `1Gi` | Kubernetes configuration; validated against the resource schema. |

### podSecurityContext

Pod filesystem ownership and seccomp.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `podSecurityContext.runAsUser` | `33` | Kubernetes configuration; validated against the resource schema. |
| `podSecurityContext.runAsGroup` | `33` | Kubernetes configuration; validated against the resource schema. |
| `podSecurityContext.runAsNonRoot` | `true` | Kubernetes configuration; validated against the resource schema. |
| `podSecurityContext.fsGroup` | `33` | Kubernetes configuration; validated against the resource schema. |
| `podSecurityContext.fsGroupChangePolicy` | `OnRootMismatch` | Kubernetes configuration; validated against the resource schema. |
| `podSecurityContext.seccompProfile.type` | `RuntimeDefault` | Kubernetes configuration; validated against the resource schema. |

### securityContext

Container hardening applied to web, init, cron and worker.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `securityContext.allowPrivilegeEscalation` | `false` | Kubernetes configuration; validated against the resource schema. |
| `securityContext.readOnlyRootFilesystem` | `true` | Kubernetes configuration; validated against the resource schema. |
| `securityContext.capabilities.drop` | `["ALL"]` | Kubernetes configuration; validated against the resource schema. |

### terminationGracePeriodSeconds

Grace period for Apache and in-flight tasks before Kubernetes terminates pods.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `terminationGracePeriodSeconds` | `120` | Grace period for Apache and in-flight tasks before Kubernetes terminates pods. |

### podLabels

Pod labels; selector labels are reserved.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `podLabels` | `{}` | Pod labels; selector labels are reserved. |

### podAnnotations

Pod annotations.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `podAnnotations` | `{}` | Pod annotations. |

### nodeSelector

Node placement.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `nodeSelector` | `{}` | Node placement. |

### tolerations

Node taint tolerations.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `tolerations` | `[]` | Node taint tolerations. |

### affinity

Pod affinity and anti-affinity.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `affinity` | `{}` | Pod affinity and anti-affinity. |

### topologySpreadConstraints

Topology spread constraints.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `topologySpreadConstraints` | `[]` | Topology spread constraints. |

### priorityClassName

Scheduling priority class.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `priorityClassName` | `""` | Scheduling priority class. |

### extraVolumes

Extra volumes for CA certificates or trusted extensions.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `extraVolumes` | `[]` | Extra volumes for CA certificates or trusted extensions. |

### extraVolumeMounts

Extra mounts shared by PHP containers.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `extraVolumeMounts` | `[]` | Extra mounts shared by PHP containers. |

### serviceAccount

Dedicated service account configuration.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `serviceAccount.create` | `true` | Create the account. |
| `serviceAccount.name` | `""` | Account name override. |
| `serviceAccount.annotations` | `{}` | Account annotations. |

### service

Web service options.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `service.type` | `ClusterIP` | Service type. |
| `service.port` | `80` | Service port; Apache listens on unprivileged 8080. |
| `service.annotations` | `{}` | Service annotations. |

### ingress

Ingress configuration; configure moodle.wwwroot consistently.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `ingress.enabled` | `false` | Render an Ingress. |
| `ingress.ingressClassName` | `""` | Ingress controller class. |
| `ingress.annotations` | `{}` | Controller-specific annotations, including upload limits. |
| `ingress.hosts` | `[]` | Host/path definitions. |
| `ingress.tls` | `[]` | TLS certificate references. |

### gatewayAPI

Canonical Gateway API integration.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `gatewayAPI.enabled` | `false` | Render HTTPRoutes. |
| `gatewayAPI.httpRoutes` | `[]` | HTTPRoute definitions with parentRefs, hostnames and rules. |

### externalSecrets

Canonical External Secrets integration.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `externalSecrets.enabled` | `false` | Render ExternalSecret objects; operator must already exist. |
| `externalSecrets.refreshInterval` | `1h` | Default refresh interval. |
| `externalSecrets.items` | `[]` | ExternalSecret definitions containing complete specs. |

### autoscaling

Autoscaling requires shared data and Redis sessions.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `autoscaling.enabled` | `false` | Enable HPA. |
| `autoscaling.minReplicas` | `2` | Minimum web replicas. |
| `autoscaling.maxReplicas` | `5` | Maximum web replicas. |
| `autoscaling.targetCPUUtilizationPercentage` | `70` | Target CPU utilization percentage. |

### pdb

Voluntary disruption protection.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `pdb.enabled` | `false` | Render PDB; use only with multiple web replicas. |
| `pdb.minAvailable` | `1` | Minimum healthy web pods. |

### networkPolicy

Network isolation; additional external endpoints use explicit extraEgress rules.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `networkPolicy.enabled` | `false` | Enable NetworkPolicy. |
| `networkPolicy.ingressFrom` | `[]` | Allowed ingress peers; empty permits all sources to the web port. |
| `networkPolicy.extraEgress` | `[]` | Additional egress rules for external DB/Redis, SMTP, plugins or storage. |

### Optional Service IP fields

| Parameter | Default | Meaning |
| --- | --- | --- |
| `service.ipFamilyPolicy` | omitted | SingleStack, PreferDualStack or RequireDualStack |
| `service.ipFamilies` | omitted | Ordered IPv4/IPv6 list, at most two unique entries |

## Upstream and related charts

- [Moodle documentation](https://docs.moodle.org/502/en/Main_page)
- [PostgreSQL](../postgresql/README.md)
- [MySQL](../mysql/README.md)
- [MariaDB](../mariadb/README.md)
- [Redis](../redis/README.md)
- [Research](docs/research.md)
