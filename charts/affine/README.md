# AFFiNE Helm Chart

AFFiNE collaborative workspaces with the official image, private administrator
initialization, pgvector PostgreSQL, authenticated Redis and persistent native
identity. The chart uses one Recreate application replica with explicit storage and
dependency contracts.

## Operational features

- Native first-administrator API runs on verified loopback before public startup.
- Retained bootstrap Secret and native SEC1 key; existing identities are preserved.
- Non-root application, read-only image filesystem, bounded writable paths and no
  Kubernetes API token.
- HelmForge PostgreSQL and Redis dependencies, or independently configured external
  services with verified TLS and operator-managed credentials.
- Separate Prisma and SQLx TLS settings, including certificate and hostname checks
  for both native PostgreSQL clients.
- Authenticated native Socket.IO/Yjs synchronization, private workspace/blob access
  and dependency-aware readiness.
- Native Prometheus endpoint, private metrics Service, ServiceMonitor and
  PrometheusRule; scoped NetworkPolicy and DNS/dependency egress.
- Ingress, canonical `gatewayAPI.httpRoutes[]`, dual-stack Services and External
  Secrets through the standard `items[]` contract.
- Coordinated PostgreSQL/configuration/storage recovery procedure and a dedicated
  fresh-database/fresh-PVC acceptance scenario.

## Architecture

The chart runs one AFFiNE application Pod with a bootstrap init container and a
Recreate update strategy. The Pod owns the native configuration, signing key and
filesystem objects on one retained PVC. PostgreSQL stores relational and document
metadata; Redis provides cache, sessions, collaboration and background queues. The
default dependencies are HelmForge PostgreSQL 2.1.1 and Redis 3.1.0, both fetched
from the HelmForge OCI registry.

Ingress or Gateway API routes terminate at the public Service. Native metrics use
a separate private Service and explicit NetworkPolicy peers. The chart deliberately
keeps `replicaCount=1`: increasing replicas does not create a supported HA topology
for the local identity and blob store. See [DESIGN.md](DESIGN.md) for the complete
topology, trust boundaries, decisions and non-goals.

## Installation

Create the namespace and an administrator credential through the cluster's approved
Secret-management workflow. Use a password containing 16 to 32 characters.

```yaml
bootstrap:
  email: owner@example.com
  existingSecret: affine-administrator
  passwordKey: password
server:
  publicUrl: https://knowledge.example.com
ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-body-size: 100m
  hosts:
    - host: knowledge.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: knowledge-tls
      hosts: [knowledge.example.com]
```

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm upgrade --install affine helmforge/affine \
  --namespace knowledge --create-namespace --values production-values.yaml
```

The initial password is generated and retained when no existing Secret or explicit
password is supplied. Changing the bootstrap Secret does not reset an existing
account. Configure the exact browser-visible origin before first use and provide
the edge certificate through the selected controller.

## Configuration

`values.schema.json` validates the parent chart and the documented PostgreSQL and
Redis override surface during `helm lint`, template, install and upgrade. Inspect
the complete contract with `helm show values helmforge/affine`. The most important
settings are:

| Parameter | Default | Purpose |
| --- | --- | --- |
| `replicaCount` | `1` | Enforce the supported single-writer application topology. |
| `image.tag` | `0.27.4` | Pin the official AFFiNE application image. |
| `server.port` | `3010` | Configure the real AFFiNE listener and named Service target. |
| `server.publicUrl` | `""` | Set the exact browser-visible origin used by AFFiNE. |
| `bootstrap.email` | `admin@example.test` | Define the first administrator identity. |
| `bootstrap.existingSecret` | `""` | Read the initial administrator password from an existing Secret. |
| `persistence.size` | `20Gi` | Size configuration, identity, blob and avatar storage. |
| `persistence.retain` | `true` | Keep the application PVC when the release is removed. |
| `postgresql.enabled` | `true` | Deploy the HelmForge PostgreSQL dependency with pgvector. |
| `database.host` | `""` | Select an external PostgreSQL host when the dependency is disabled. |
| `database.tls.enabled` | `true` | Verify external PostgreSQL encryption, chain and hostname. |
| `redis.enabled` | `true` | Deploy authenticated persistent HelmForge Redis. |
| `cache.host` | `""` | Select an external standalone Redis endpoint. |
| `cache.tls.enabled` | `true` | Verify external Redis encryption, chain and hostname. |
| `networkPolicy.enabled` | `true` | Render ingress and dependency-aware egress isolation. |
| `metrics.enabled` | `false` | Enable the unauthenticated private native metrics endpoint. |
| `metrics.serviceMonitor.enabled` | `false` | Render a ServiceMonitor for an installed Prometheus Operator. |
| `ingress.enabled` | `false` | Expose the public Service through an existing Ingress controller. |
| `gatewayAPI.enabled` | `false` | Render HTTPRoutes for an existing Gateway. |

Application credentials belong in existing Secrets or External Secrets. Keep
`extraEnv` for non-managed upstream settings; chart-owned connection, identity,
listener and security variables are rejected to prevent ambiguous configuration.

## Dependencies and persistence

Defaults enable PostgreSQL 16 with the official pgvector image and authenticated
Redis. The application PVC stores native configuration, private keys, blobs and
avatars. PostgreSQL stores users, permissions, document state and blob metadata.
Redis uses several logical databases for cache, sessions, collaboration and queues.

Set `postgresql.enabled=false` to use `database.*`, or `redis.enabled=false` to use
`cache.*`. Both external transports enable TLS by default. Configure the server
hostname, credential Secret, optional CA Secret and appropriate egress rules.
The PostgreSQL DBA must install `vector` before application migrations. The chart
rejects conflicting bundled/external settings and unsupported Redis topologies.

The application requires one replica because local storage and background processing
need a coordinated topology. Recreate avoids concurrent writers during an upgrade.
Size the application PVC, PostgreSQL volume and Redis memory/storage independently.
Retain the complete matching recovery set; PVC retention is not a backup.

## Networking and monitoring

Use `ingress.ingressClassName` for Ingress, or enable `gatewayAPI.enabled` and provide
`gatewayAPI.httpRoutes[]`. Each route requires parent references. Omitted backends
target the application Service; multiple routes, matches and filters use the standard
HelmForge contract. Controllers must support WebSocket upgrades and the configured
upload limits. Controller installation and edge certificate provisioning are separate.

Enable `metrics.enabled` and the desired monitoring CRDs. The native endpoint has
no authentication and remains on a separate private Service; restrict scraper peers
through `metrics.ingressFrom`. The metric switch also activates upstream tracing, so
review its destination and network policy. Native storage and collaboration metrics
are exercised by the behavioral tests, with a real Prometheus scrape and loaded rule.

## Examples

- [Production Ingress](examples/production-ingress.yaml) demonstrates HTTPS,
  WebSocket timeouts, resource sizing and retained storage.
- [External TLS dependencies](examples/external-tls.yaml) demonstrates independent
  PostgreSQL and Redis Secrets, CA trust and egress peers.
- [Gateway API, External Secrets and monitoring](examples/gateway-eso-monitoring.yaml)
  demonstrates canonical HTTPRoutes, a managed bootstrap Secret, ServiceMonitor
  and PrometheusRule.

Render an example before applying it:

```bash
helm dependency build charts/affine
helm template affine charts/affine \
  --namespace knowledge \
  --values charts/affine/examples/production-ingress.yaml
```

Every hostname, Secret reference, storage class, Gateway parent and NetworkPolicy
peer in the examples is deployment-specific and must be replaced.

## Important operations

- Preserve `config/private.key` and database signing records across upgrades and
  restore. An existing user database with a missing key fails initialization.
- Back up before upgrading. Native schema and data migrations are serialized;
  unresolved migration history requires explicit repair.
- Public signup, OAuth signup and guest demo workspaces are disabled in chart-managed
  defaults. Review administrator-owned database configuration before changing them.
- Rotate connection credentials and CA trust through a controlled restart.
- Keep filesystem/configuration archives encrypted and access-controlled; generated
  configuration includes database credentials.

## Troubleshooting

If bootstrap does not complete, inspect the init container before restarting the
Pod. A missing pgvector extension, untrusted dependency certificate, mismatched
hostname, unresolved migration or absent original private key is a hard failure by
design.

```bash
kubectl -n knowledge logs deployment/affine -c bootstrap
kubectl -n knowledge describe pod -l app.kubernetes.io/name=affine
kubectl -n knowledge get events --sort-by=.lastTimestamp
```

If the Pod is running but not Ready, check the application container and verify a
fresh PostgreSQL query, authenticated Redis PING and `/info` response. For rejected
uploads or disconnected collaborators, verify controller WebSocket support, body
size and timeouts. For metrics failures, confirm that `metrics.enabled=true`, the
Prometheus Operator CRDs exist and `metrics.ingressFrom` selects the scraper.

Do not delete the application PVC to repair startup. It contains the private key
that must match database signing records. Follow [coordinated recovery](docs/recovery.md)
when restoring or replacing state.

## Documentation

- [Administrator initialization and access](docs/onboarding.md)
- [PostgreSQL, Redis and TLS](docs/dependencies.md)
- [Native monitoring](docs/monitoring.md)
- [Coordinated recovery](docs/recovery.md)
- [Design and boundaries](DESIGN.md)

## Validation status

The complete HelmForge gate passed all 21 layers, including 31 Helm assertions and
11 isolated k3d runtime scenarios. Acceptance covers private administrator setup,
closed registration, native document collaboration and edits after replacement,
PostgreSQL and Redis certificate/hostname rejection, a real Prometheus
ServiceMonitor scrape, External Secrets, and recovery into a new database and PVC.
The production scenario also verifies that application and dependency Pods have
no projected Kubernetes API tokens.

## Security Scan: `affine`

| Framework | Score |
| --- | --- |
| Overall | **98.96%** |
| MITRE | **99.16%** |
| NSA | **98.29%** |
| SOC2 | **97.14%** |

Kubescape 4.0.13, default rendered manifests, 2026-09-10. No controls were suppressed.
C-0012 matches the literal private-key format check in the bootstrap program; the
ConfigMap contains code, not a private key. C-0034 identifies the bundled Redis
dependency's missing Pod-level token-automount field. Redis has a dedicated account
without RBAC grants and denied egress. The production example shares the AFFiNE
account with token automount disabled; its runtime test checks all dependency Pods
for projected API tokens. See [dependency hardening](docs/dependencies.md).
This manifest scan does not replace application review or image vulnerability management.
