# Pimcore Helm Chart

Production-oriented deployment of [Pimcore](https://pimcore.com), the
PHP/Symfony platform for PIM, MDM, DAM, CDP, DXP/CMS, and digital commerce.

This chart targets Pimcore `2026.2.10` and pins the official multi-architecture
PHP 8.5 runtime `pimcore/pimcore:php8.5.9-max-v5.2-hardened`. It models the
upstream topology instead of treating the runtime image as a complete
application:

- nginx and PHP-FPM in one web pod with independent health checks;
- Symfony Messenger workers with the official Pimcore transport set;
- `pimcore:maintenance` CronJob;
- HelmForge MariaDB, RabbitMQ, and optional Redis dependencies;
- Mercure for Pimcore Studio real-time updates;
- project and public-asset persistence;
- explicit installation and product-registration workflow;
- Ingress, Gateway API, dual-stack Service, NetworkPolicy, PDB, and ESO.

## Important application-image boundary

The official `pimcore/pimcore` image is a PHP runtime. It does not contain a
Pimcore project. A production deployment must build project code, locked
Composer dependencies, configuration, and generated classes into an immutable
image based on that runtime.

For evaluation and first installation, the default bootstrap downloads the
exact `pimcore/skeleton:2026.2.0` Composer project into a persistent project
volume. This mode is intentionally single-replica and requires outbound HTTPS.
It is not a replacement for an immutable production image.

Pimcore 2026 requires product registration before installation or use. The
chart never invents or reuses registration data. Installation runs only when
`install.enabled=true` and a matching product key, instance identifier, and
encryption secret are supplied.

## Install

```bash
helm install pimcore oci://ghcr.io/helmforgedev/helm/pimcore \
  --namespace pimcore \
  --create-namespace
```

Wait for the runtime:

```bash
kubectl wait -n pimcore \
  --for=condition=available deployment/pimcore \
  --timeout=300s
kubectl port-forward -n pimcore service/pimcore 8080:80
curl -fsS http://127.0.0.1:8080/healthz
curl -fsS http://127.0.0.1:8080/readyz
```

The two endpoints verify nginx and PHP-FPM. The Pimcore UI is available only
after the registered installer completes.

## Registered installation

Create a Secret containing one matching registration set:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: pimcore-registration
type: Opaque
stringData:
  application-secret: replace-with-a-long-random-value
  admin-password: replace-with-a-strong-password
  product-key: replace-with-the-registered-product-key
  instance-identifier: replace-with-the-registered-uuid
  encryption-secret: replace-with-the-matching-defuse-key
  mercure-jwt-key: replace-with-a-long-random-value
```

Run the installer:

```bash
helm upgrade pimcore oci://ghcr.io/helmforgedev/helm/pimcore \
  --namespace pimcore \
  --reuse-values \
  --set auth.existingSecret=pimcore-registration \
  --set install.enabled=true
```

Inspect the hook Job and disable the one-time installer after success:

```bash
kubectl logs -n pimcore job/pimcore-install
helm upgrade pimcore oci://ghcr.io/helmforgedev/helm/pimcore \
  --namespace pimcore \
  --reuse-values \
  --set install.enabled=false \
  --set worker.enabled=true \
  --set maintenance.enabled=true
```

## Production image

Build a project image outside Kubernetes:

```dockerfile
FROM pimcore/pimcore:php8.5.9-max-v5.2-hardened

WORKDIR /var/www/html
COPY --chown=www-data:www-data . .
RUN composer install \
      --no-dev \
      --no-interaction \
      --no-progress \
      --prefer-dist \
      --optimize-autoloader \
  && test -f bin/console
```

Deploy it with bootstrap and project persistence disabled:

```yaml
image:
  repository: registry.example.com/platform/pimcore-project
  tag: "2026.2.10-1"

project:
  bootstrap:
    enabled: false
  persistence:
    enabled: false

auth:
  existingSecret: pimcore-registration

worker:
  enabled: true

maintenance:
  enabled: true
```

With project persistence disabled, nginx, PHP-FPM, workers, and maintenance use
the project code directly from the immutable image. Only public assets remain
mounted from their dedicated persistent volume.

## Database

MariaDB is enabled by default with the upstream-required `utf8mb4` character
set and `utf8mb4_unicode_520_ci` collation:

```yaml
mariadb:
  standalone:
    persistence:
      size: 20Gi
```

Use a managed MariaDB service:

```yaml
mariadb:
  enabled: false

database:
  mode: external
  serverVersion: mariadb-11.4.7
  external:
    host: mariadb.database.svc
    name: pimcore
    username: pimcore
    existingSecret: pimcore-database
    existingSecretPasswordKey: password
```

The chart constructs `DATABASE_URL` at process start so passwords remain
Secret-backed and do not appear in rendered manifests. Set
`database.serverVersion` to the exact Doctrine-compatible external engine
version; the default matches the bundled MariaDB 12.3.2 dependency.

## RabbitMQ and workers

The default RabbitMQ dependency uses quorum queues and persistent storage.
Workers consume the transports recommended by the current Pimcore skeleton:

- `pimcore_generic_execution_engine`
- `pimcore_generic_data_index_queue`
- `scheduler_generic_data_index`
- `pimcore_core`
- `pimcore_maintenance`
- `pimcore_scheduled_tasks`
- `pimcore_image_optimize`
- `pimcore_asset_update`

Use an external broker:

```yaml
rabbitmq:
  enabled: false

queue:
  mode: external
  external:
    host: rabbitmq.messaging.svc
    username: pimcore
    vhost: pimcore
    existingSecret: pimcore-rabbitmq
```

The chart constructs the AMQP DSN in the container. URL-encode a custom vhost.

## Redis

The upstream skeleton starts Redis but does not activate a Redis-backed Symfony
cache or session handler. The chart therefore keeps Redis optional and exposes
connection values only when requested:

```yaml
cache:
  enabled: true

redis:
  enabled: true
```

Your project configuration must consume `REDIS_HOST`, `REDIS_PORT`,
`REDIS_PASSWORD`, and `REDIS_TLS`.

## Mercure

Mercure is enabled for Pimcore Studio. The internal hub is exposed through the
main nginx Service at `/hub`, avoiding a separate public origin. Anonymous
subscriptions match the skeleton development topology and should be disabled
after the project configures subscriber authorization:

```yaml
mercure:
  anonymous: false
```

## Persistence and scaling

Bootstrap mode uses a project PVC. Production immutable-image mode should
disable it. Public assets have a separate PVC:

```yaml
assets:
  persistence:
    enabled: true
    storageClass: nfs-rwx
    accessModes:
      - ReadWriteMany
    size: 100Gi
```

The chart rejects multiple web replicas with a chart-created RWO project or
asset PVC. For HA:

1. use an immutable project image;
2. disable project persistence and bootstrap;
3. provide RWX assets or configure project-specific object storage;
4. use external HA MariaDB, RabbitMQ, and Redis services;
5. configure pod topology and a PDB.

## OpenSearch

Generic Data Index installations can require OpenSearch. It is deliberately not
bundled because supported versions and credentials belong to the application
project:

```yaml
pimcore:
  opensearchDSN: opensearch://user:password@opensearch.search.svc:9200
```

Prefer `pimcore.extraEnv` plus a Secret reference when the DSN contains
credentials.

## External Secrets

The chart implements the canonical `externalSecrets.items[]` contract:

```yaml
auth:
  existingSecret: pimcore-registration

externalSecrets:
  enabled: true
  items:
    - name: registration
      spec:
        secretStoreRef:
          name: production
          kind: ClusterSecretStore
        target:
          name: pimcore-registration
          creationPolicy: Owner
        dataFrom:
          - extract:
              key: pimcore/production
```

The target Secret must contain every key configured under `auth`.

## Routing

Ingress:

```yaml
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: pimcore.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: pimcore-tls
      hosts:
        - pimcore.example.com
```

Gateway API:

```yaml
gatewayAPI:
  enabled: true
  httpRoutes:
    - name: public
      parentRefs:
        - name: public-gateway
          namespace: gateways
      hostnames:
        - pimcore.example.com
```

## Network policy

NetworkPolicy is opt-in. When egress enforcement is enabled, the chart permits
DNS only to the configured cluster DNS namespace/pod selectors, plus
chart-managed MariaDB, RabbitMQ, Redis, and Mercure traffic. Bootstrap also
requires outbound HTTPS:

```yaml
networkPolicy:
  enabled: true
  egress:
    enabled: true
    extraEgress:
      - ports:
          - protocol: TCP
            port: 443
```

Production deployments should restrict that rule to known Composer or service
CIDRs, or remove it when using an immutable project image.

## Backup and restore

A complete recovery point includes:

- MariaDB;
- public assets or the external object store;
- the immutable application image and its configuration;
- registration Secret values;
- RabbitMQ only when durable in-flight jobs must survive the recovery point.

Do not back up cache directories as authoritative data. Test restore and
`pimcore:deployment:classes-rebuild` procedures against the application
project.

## Security Scan

### Security Scan: `pimcore`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **89.43%** |

Security posture acceptable.

Local details:

- Tool: Kubescape v4.0.9
- Command: `kubescape scan framework "MITRE,NSA,SOC2" .tmp/pimcore-render.yaml`
- Result: 0 critical and 0 high failed resources, resource summary score 89.43%.

Runtime images are official, exact, multi-architecture tags. The default PHP
image is the upstream hardened variant. Containers drop all Linux capabilities,
disable privilege escalation, run as non-root users, and do not automount
ServiceAccount tokens. nginx and the Helm test use read-only root filesystems.
PHP workloads retain a writable root because upstream Pimcore and Composer
write project/runtime paths without a complete relocation contract; immutable
project images should minimize those paths and keep application data on
explicit volumes.

## Validation

Run the full HelmForge gate:

```bash
make validate-chart CHART=pimcore
```

This covers dependencies, strict lint, default and CI rendering, unit tests,
kubeconform with real CRD schemas, Artifact Hub lint, and behavioral k3d
deployment.

## More documentation

- [Design](DESIGN.md)
- [Installation and registration](docs/installation.md)
- [Production operations](docs/production.md)
- [Networking](docs/networking.md)
- [Secrets](docs/secrets.md)
- [Research and differentiation](docs/research.md)
