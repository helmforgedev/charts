<!-- SPDX-License-Identifier: Apache-2.0 -->
# Apache Superset configuration

Superset runs a Gunicorn web Deployment, optional Celery worker Deployment,
optional single-replica Celery Beat Deployment, and a managed initialization
Job. PostgreSQL stores durable metadata. Redis provides caches and the Celery
broker and result backend.

## Application and image

| Value | Default | Purpose |
|---|---|---|
| `image.repository` | `docker.io/apache/superset` | Official or derived image repository. |
| `image.tag` | `6.1.0` | Immutable image tag. |
| `superset.existingSecret` | empty | Secret containing the administrator password and `SECRET_KEY`. |
| `superset.installPythonPackages` | `true` | Install PostgreSQL, Redis, and extra Python packages at startup. |
| `superset.extraPythonPackages` | `[]` | Shell-safe package specifications added to every Superset process. |
| `superset.extraConfig` | empty | Trusted Python appended to `superset_config.py`. |

The official 6.1.0 release image is lean. The compatibility path installs
`psycopg2-binary`, `redis`, and configured extras into an ephemeral directory.
For production, build those packages into a derived image and set
`superset.installPythonPackages=false`.

The chart preserves an auto-generated administrator password and `SECRET_KEY`
across upgrades by reading the existing release Secret. Production deployments
should use an operator-managed `superset.existingSecret` with the configured
`existingSecretPasswordKey` and `existingSecretSecretKeyKey`.

## Web, worker, and scheduler

| Value | Default | Purpose |
|---|---|---|
| `web.replicaCount` | `1` | Web pod count. |
| `web.containerPort` | `8088` | Actual Gunicorn listener. |
| `web.workers` | `2` | Gunicorn processes per web pod. |
| `web.timeout` | `120` | Gunicorn worker timeout in seconds. |
| `worker.enabled` | `true` | Create Celery workers. |
| `worker.replicaCount` | `1` | Celery worker pod count. |
| `worker.concurrency` | `2` | Concurrent tasks per worker. |
| `beat.enabled` | `true` | Create one Celery Beat scheduler. |

`service.port` is independent of `web.containerPort`. The Service uses the
named `http` target port, and the probes follow the container listener. Keep
Celery Beat at one replica to prevent duplicate scheduling.

## Initialization

`init.enabled=true` creates a revisioned Job that runs migrations, creates the
administrator, initializes roles and permissions, and optionally loads example
data. The web, worker, and Beat pods use a minimal namespaced Role to wait for
that Job. When initialization is disabled, every web pod start performs
migrations and role initialization before Gunicorn. Keep one web replica while
that fallback remains enabled, or enable the init Job before scaling.

The API token is mounted into application pods only when managed initialization
is enabled. The initialization Job never receives a token.

## PostgreSQL

For the bundled database, keep the modes aligned:

```yaml
database:
  mode: subchart

postgresql:
  enabled: true
  architecture: standalone
```

For an external database, disable the subchart and provide an existing Secret:

```yaml
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

postgresql:
  enabled: false
```

Supported SSL modes are `disable`, `allow`, `prefer`, `require`, `verify-ca`,
and `verify-full`. Credential values are URL-encoded inside Python before the
SQLAlchemy URI is built.

## Redis

Bundled Redis must keep authentication enabled. Standalone and replication
architectures are supported; replication mode uses the writable primary.

```yaml
redisConfig:
  mode: subchart

redis:
  enabled: true
  architecture: standalone
  auth:
    enabled: true
```

External Redis requires a password or existing Secret. Enable TLS for a
`rediss://` connection:

```yaml
redisConfig:
  mode: external
  external:
    host: redis.example.com
    port: 6379
    db: 0
    tls: true
    existingSecret: superset-redis
    existingSecretPasswordKey: password

redis:
  enabled: false
```

## Security and network policy

The default security contexts use UID/GID 1000, a read-only root filesystem,
`RuntimeDefault` seccomp, no privilege escalation, and no Linux capabilities.
Do not weaken them without validating the exact image requirement.

The default NetworkPolicy permits the web listener from any source and allows
all egress. Restrict ingress to the ingress-controller namespace:

```yaml
networkPolicy:
  enabled: true
  ingressFrom:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-nginx
```

Replace `networkPolicy.egress` with environment-specific rules only after
including DNS, PostgreSQL, Redis, the Kubernetes API server while
`init.enabled=true`, package-index access when runtime installs are enabled,
and every external data source queried by Superset.

## Related guides

- [Chart design](../DESIGN.md)
- [Operations](operations.md)
- [Security](security.md)
- [External datastore example](../examples/external-datastores.yaml)
- [Production example](../examples/production.yaml)
