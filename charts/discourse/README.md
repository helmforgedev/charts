<!-- SPDX-License-Identifier: Apache-2.0 -->

# Discourse Helm Chart

Deploy Discourse on Kubernetes with the official upstream ESR image, immutable
image digests, PostgreSQL with pgvector, Redis, persistent shared storage, and
HelmForge validation.

Warning: This chart is beta and experimental. Discourse classifies its official
container image and Kubernetes deployments as unsupported for production. The
chart deliberately does not claim production readiness or upstream support.

## Features

- Official `discourse/discourse:2026.7.4` image pinned by OCI index digest.
- One enforced replica with `Recreate` updates and persistent `/shared` state.
- HelmForge PostgreSQL and Redis subcharts enabled by default.
- Official pgvector image for the extensions required by bundled Discourse plugins.
- External PostgreSQL and Redis contracts with existing Secret support.
- Ingress, Gateway API, dual-stack Service, NetworkPolicy, and canonical External Secrets.
- Startup, readiness, and liveness probes against upstream `/srv/status`.
- Scheduling, pod metadata, extra environment, volume, and manifest extensions.

## Architecture

The Service presents `service.port` and targets the fixed named `http` listener
on port 80. The upstream Nginx runtime does not support changing that listener.
PostgreSQL stores relational data, Redis provides cache/coordination, and the
`/shared` PVC stores uploads, backups, logs, and runtime state. See
[DESIGN.md](DESIGN.md) for the complete trust and production boundaries.

## Installation

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install discourse helmforge/discourse
```

OCI installation:

```bash
helm install discourse oci://ghcr.io/helmforgedev/helm/discourse
```

The first boot runs migrations and asset compilation. It commonly takes several
minutes even after the 5.2 GB upstream image is available on the node.

## Configuration

| Key | Default | Description |
| --- | --- | --- |
| `replicaCount` | `1` | Enforced singleton application replica. |
| `image.tag` | `2026.7.4` | Official Discourse ESR tag. |
| `image.digest` | pinned | Required immutable multi-architecture digest. |
| `discourse.hostname` | `discourse.localhost` | Public forum hostname. |
| `discourse.developerEmails` | `admin@example.com` | Initial developer email list. |
| `discourse.existingSecret` | `""` | Existing Secret containing `secret-key-base`. |
| `database.mode` | `postgresql` | Bundled `postgresql` or `external`. |
| `postgresql.enabled` | `true` | Deploy bundled PostgreSQL with pgvector. |
| `redis.enabled` | `true` | Deploy bundled Redis. |
| `persistence.enabled` | `true` | Persist upstream `/shared`. |
| `service.port` | `80` | Client-facing Service port. |
| `ingress.enabled` | `false` | Render an Ingress. |
| `gatewayAPI.enabled` | `false` | Render a Gateway API HTTPRoute. |
| `networkPolicy.enabled` | `false` | Enforce chart NetworkPolicy rules. |
| `externalSecrets.enabled` | `false` | Render canonical `ExternalSecret` items. |

Inspect the complete contract with `helm show values helmforge/discourse`.

### External PostgreSQL and Redis

External PostgreSQL must be version 15 or newer and provide `pg_trgm`,
`unaccent`, and `vector`. The configured application user must own the database
or otherwise be allowed to create those extensions and run migrations.

```yaml
postgresql:
  enabled: false
database:
  mode: external
  external:
    host: postgresql.database.svc.cluster.local
    name: discourse
    username: discourse
    existingSecret: discourse-database
    existingSecretPasswordKey: database-password

redis:
  enabled: false
  external:
    host: redis.cache.svc.cluster.local
    existingSecret: discourse-redis
    existingSecretPasswordKey: redis-password
```

### Routing

Set `discourse.hostname` to the same public hostname used by Ingress or
HTTPRoute. TLS termination belongs to the ingress controller or Gateway.

```yaml
discourse:
  hostname: forum.example.com
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: forum.example.com
      paths:
        - path: /
          pathType: Prefix
```

### External Secrets

The chart does not install External Secrets Operator. Each
`externalSecrets.items[]` entry carries a complete ESO spec and can project a
Secret referenced by application, database, Redis, or extra environment values.
See [docs/external-secrets.md](docs/external-secrets.md).

## Security

The official image requires UID 0 and a writable root filesystem. The chart
documents this upstream exception, disables privilege escalation, drops all
capabilities, and adds only `CHOWN`, `DAC_OVERRIDE`, `FOWNER`,
`NET_BIND_SERVICE`, `SETGID`, and `SETUID`. Service-account token automounting is
disabled. These controls reduce exposure but do not make the unsupported
upstream runtime production-ready.

Keep credentials in existing Secrets or External Secrets. Never commit real
passwords. Enable and tailor NetworkPolicy only after enumerating database,
Redis, DNS, HTTPS, SMTP, and integration destinations.

## Operations

```bash
DEPLOYMENT=$(kubectl get deployment -n NAMESPACE \
  -l app.kubernetes.io/instance=RELEASE \
  -o jsonpath='{.items[0].metadata.name}')
HOSTNAME=discourse.localhost # Replace with the configured discourse.hostname.
kubectl rollout status deployment/"$DEPLOYMENT" -n NAMESPACE --timeout=20m
kubectl get pods,svc,pvc -n NAMESPACE -l app.kubernetes.io/instance=RELEASE
kubectl logs deployment/"$DEPLOYMENT" -n NAMESPACE -c discourse --tail=300
kubectl exec deployment/"$DEPLOYMENT" -n NAMESPACE -- \
  curl -fsS -H "Host: ${HOSTNAME}" http://127.0.0.1/srv/status
```

Back up both PostgreSQL and `/shared`; neither is a substitute for the other.
Upgrade only one release at a time, retain `Recreate`, and test restore and
rollback in an isolated namespace. See [docs/operations.md](docs/operations.md),
[docs/backup-restore.md](docs/backup-restore.md), and
[docs/security.md](docs/security.md).

## Known Limitations

- Upstream does not support this image or Kubernetes path for production.
- Exactly one Discourse replica is supported.
- The image is approximately 5.2 GB expanded and first boot is resource intensive.
- Root and writable root filesystem are required upstream exceptions.
- Plugins require a custom image; the chart does not compile plugins at startup.
- There is no native chart-managed Prometheus endpoint or ServiceMonitor.
- A PDB cannot create availability for a singleton and is disabled by default.

## Resources Generated

| Resource | Condition |
| --- | --- |
| Deployment and Service | Always |
| ServiceAccount | `serviceAccount.create` |
| Secret and PVC | No corresponding existing resource is configured |
| PostgreSQL and Redis resources | Corresponding dependency enabled |
| Ingress or HTTPRoute | Corresponding routing feature enabled |
| NetworkPolicy or PDB | Explicitly enabled |
| ExternalSecret | `externalSecrets.enabled` with items |
| Extra manifests | Entries supplied in `extraManifests` |

## More Information

- [Design](DESIGN.md)
- [Operations](docs/operations.md)
- [Backup and restore](docs/backup-restore.md)
- [External Secrets](docs/external-secrets.md)
- [Security](docs/security.md)
- [Upstream Discourse](https://github.com/discourse/discourse)
- [Upstream container project](https://github.com/discourse/discourse_docker)

🟢 Security Scan: discourse

| Framework | Score |
| --- | --- |
| MITRE + NSA + SOC2 | **90.404045%** |

✅ Security posture acceptable.
