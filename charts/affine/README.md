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

## Install

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
