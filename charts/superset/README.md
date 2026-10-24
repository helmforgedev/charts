# Apache Superset

Apache Superset is a modern, enterprise-ready business intelligence web application
for data exploration and visualization. It supports 60+ database connectors,
interactive dashboards, SQL Lab, and a rich set of visualizations.

## Features

- **Three-component architecture** — web server (Gunicorn), Celery worker, and Celery beat scheduler as separate Deployments for independent scaling
- **Managed init Job** — ordered database migration, Superset initialization, and administrator creation on every release revision
- **PostgreSQL subchart** — bundled metadata store with option for external database
- **Redis subchart** — bundled Celery broker and result backend with option for external Redis
- **superset_config.py via ConfigMap** — extend Superset configuration through `superset.extraConfig`
- **Additional Python packages** — install pinned database drivers consistently in web, worker, beat, and init
- **Auto-generated secrets** — admin password, Flask SECRET_KEY, database and Redis passwords
- **Health probes** — startup, liveness, and readiness probes on `/health`
- **Hardened runtime** — non-root containers, read-only root filesystem, seccomp, dropped capabilities, and scoped wait RBAC
- **NetworkPolicy** — web-listener ingress isolation with configurable egress
- **Ingress support** — configurable with `ingressClassName` (traefik, nginx, etc.)

## Install

### Helm repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install superset helmforge/superset -f values.yaml
```

### OCI registry

```bash
helm install superset oci://ghcr.io/helmforgedev/helm/superset --version <version> -f values.yaml
```

## Upgrading from Superset 4

This chart crosses the Superset 5 and 6 major releases. Back up the metadata
database before upgrading and plan for migration downtime. The chart's init Job
runs `superset db upgrade` and `superset init` before the application workloads
become ready. Superset 6 removes `AUTH_OID`; installations using it must move to
OAuth, LDAP, or database authentication first. Custom frontend extensions may
also need changes for the React upgrade introduced in Superset 5.

Review the upstream [Superset 5 update notes](https://github.com/apache/superset/blob/5.0.0/UPDATING.md)
and [Superset 6 update notes](https://github.com/apache/superset/blob/6.1.0/UPDATING.md)
before upgrading production installations.

## Architecture

```text
Client -> Service -> web Deployment -> PostgreSQL and Redis
Celery worker Deployment -> PostgreSQL and Redis
Celery Beat Deployment -> Redis
init Job -> PostgreSQL
web, worker, and beat init containers -> init Job status
```

## Default Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `apache/superset` | Container image |
| `image.tag` | `"6.1.0"` | Immutable image tag |
| `superset.adminUsername` | `admin` | Admin username |
| `superset.adminPassword` | `""` (auto) | Admin password |
| `superset.secretKey` | `""` (auto) | Flask SECRET_KEY |
| `superset.loadExamples` | `false` | Load example dashboards |
| `superset.installPythonPackages` | `true` | Install runtime Python dependencies at process startup |
| `superset.extraPythonPackages` | `[]` | Additional Python package specifications installed in every Superset process |
| `web.replicaCount` | `1` | Web server replicas |
| `web.containerPort` | `8088` | Gunicorn listener port |
| `web.workers` | `2` | Gunicorn workers |
| `web.timeout` | `120` | Gunicorn timeout |
| `worker.enabled` | `true` | Enable Celery workers |
| `worker.replicaCount` | `1` | Worker replicas |
| `worker.concurrency` | `2` | Celery concurrency |
| `beat.enabled` | `true` | Enable Celery beat |
| `init.enabled` | `true` | Enable init job |
| `database.mode` | `subchart` | Database mode: subchart or external |
| `redisConfig.mode` | `subchart` | Redis mode: subchart or external |
| `service.type` | `ClusterIP` | Service type |
| `service.port` | `80` | Service port |
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `traefik` | Ingress class |
| `networkPolicy.enabled` | `true` | Restrict ingress to the web listener |
| `postgresql.enabled` | `true` | Enable PostgreSQL subchart |
| `postgresql.standalone.persistence.enabled` | `true` | Enable persistent storage for bundled PostgreSQL |
| `postgresql.standalone.persistence.storageClass` | `""` | Storage class for bundled PostgreSQL; empty uses the cluster default |
| `postgresql.standalone.persistence.accessModes` | `[ReadWriteOnce]` | Access modes for the bundled PostgreSQL PVC |
| `postgresql.standalone.persistence.size` | `8Gi` | Bundled PostgreSQL PVC size |
| `redis.enabled` | `true` | Enable Redis subchart |
| `redis.standalone.persistence.enabled` | `true` | Enable persistent storage for bundled Redis |
| `redis.standalone.persistence.storageClass` | `""` | Storage class for bundled Redis; empty uses the cluster default |
| `redis.standalone.persistence.accessModes` | `[ReadWriteOnce]` | Access modes for the bundled Redis PVC |
| `redis.standalone.persistence.size` | `8Gi` | Bundled Redis PVC size |

## Bundled Storage

PostgreSQL and Redis are enabled in standalone mode by default. Configure their
PVCs through each subchart's `standalone.persistence` values. Leave
`storageClass` empty to use the cluster's default StorageClass.

```yaml
postgresql:
  enabled: true
  standalone:
    persistence:
      enabled: true
      storageClass: fast-storage
      size: 20Gi

redis:
  enabled: true
  standalone:
    persistence:
      enabled: true
      storageClass: fast-storage
      size: 8Gi
```

## External Database

```yaml
postgresql:
  enabled: false

database:
  mode: external
  external:
    host: postgres.example.com
    port: 5432
    name: superset
    username: superset
    existingSecret: superset-database
    existingSecretPasswordKey: password
    sslMode: verify-full
```

## External Redis

```yaml
redis:
  enabled: false

redisConfig:
  mode: external
  external:
    host: redis.example.com
    port: 6379
    tls: true
    existingSecret: superset-redis
    existingSecretPasswordKey: password
    db: 0
```

## Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: traefik  # or nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: superset.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: superset-tls
      hosts:
        - superset.example.com
```

## Custom Configuration

Extend `superset_config.py` via `superset.extraConfig`:

```yaml
superset:
  extraConfig: |
    FEATURE_FLAGS = {
        "DASHBOARD_NATIVE_FILTERS": True,
        "DASHBOARD_CROSS_FILTERS": True,
    }
    ROW_LIMIT = 50000
```

## Additional Python Packages

Use `superset.extraPythonPackages` for development and simpler deployments that
need optional database drivers. Package entries support names with optional
version constraints. Pin a tested version so every Superset process receives the
same dependency:

```yaml
superset:
  extraPythonPackages:
    - clickhouse-connect==0.13.0
```

Superset 6.1.0 recommends `clickhouse-connect>=0.13.0` for ClickHouse and uses
the `clickhousedb://user:password@host:port/database` SQLAlchemy URI.

These packages are downloaded when the init, web, worker, and beat containers
start. Their startup therefore depends on package-index availability. For
production, build an immutable image instead:

```dockerfile
FROM apache/superset:6.1.0

USER root

RUN . /app/.venv/bin/activate && \
    uv pip install psycopg2-binary redis "clickhouse-connect==0.13.0"

USER superset
```

Push the image to your registry, then configure its immutable tag and disable
runtime installation:

```yaml
image:
  repository: registry.example.com/superset
  tag: 6.1.0-clickhouse-0.13.0

superset:
  installPythonPackages: false
```

When runtime installation is disabled, the image must contain
`psycopg2-binary`, `redis`, and every entry from `extraPythonPackages`.

## Security

The default containers run as UID/GID 1000, use `RuntimeDefault` seccomp, drop
all Linux capabilities, block privilege escalation, and mount a read-only root
filesystem. Ephemeral volumes provide only `/tmp` and `/app/superset_home` as
writable paths. The initialization and backup Jobs do not receive Kubernetes API
tokens. Application pods receive a namespaced token only while
`init.enabled=true`, because their wait container must read the initialization
Job status.

`superset.secretKey` signs sessions and encrypts sensitive metadata. The chart
preserves an auto-generated key across Helm upgrades, but production operators
should provide `superset.existingSecret` and include that Secret in the recovery
plan. Treat `superset.extraConfig` as trusted Python code.

The default NetworkPolicy permits only the configured Superset listener for
ingress and allows egress. Restrict `networkPolicy.ingressFrom` and
`networkPolicy.egress` for the ingress controller, DNS, datastores, Python
package index, external data sources used by the deployment, and the Kubernetes
API server while `init.enabled=true`.

## Troubleshooting

Inspect initialization before debugging the long-running workloads:

```bash
kubectl get job,pod -n <namespace> -l app.kubernetes.io/instance=<release>
kubectl logs -n <namespace> job/<release>-superset-init-<revision>
kubectl logs -n <namespace> deployment/<release>-superset-web --tail=200
kubectl get events -n <namespace> --sort-by=.lastTimestamp
```

If a pod waits for PostgreSQL or Redis, verify the selected datastore mode,
Service name, Secret key, TLS setting, and NetworkPolicy egress. If the web pod
is running but not Ready, test `/health` on `web.containerPort` from inside the
pod. See the operations guide for upgrade and recovery checks.

## More Information

- [Chart design](DESIGN.md)
- [Configuration](docs/configuration.md)
- [Operations](docs/operations.md)
- [Security](docs/security.md)
- [External datastores](examples/external-datastores.yaml)
- [Production example](examples/production.yaml)

### 🟢 Security Scan: `superset`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **76.46465%** |

> ✅ Security posture acceptable.

<!-- @AI-METADATA
type: chart-readme
title: Apache Superset Helm Chart
description: Apache Superset BI platform with web, worker, and beat deployments backed by PostgreSQL and Redis

keywords: superset, bi, analytics, visualization, dashboard, celery

purpose: Installation, configuration, and operational guide for the Superset Helm chart
scope: charts/superset

relations:
  - charts/superset/values.yaml
  - charts/superset/Chart.yaml
path: charts/superset/README.md
version: 1.0
date: 2026-04-01
-->
