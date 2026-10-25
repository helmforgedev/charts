# Pocket ID Helm Chart

A singleton Pocket ID identity provider using the official pinned image, passkey authentication and native OpenID
Connect. The chart initializes its first administrator privately before exposing HTTP and retains the application's
encryption key across upgrades.

## Features

- Private native first-administrator bootstrap before public HTTP starts.
- Official Pocket ID image pinned to an explicit upstream release.
- Default SQLite or bundled/external PostgreSQL with admission checks.
- Retained files and encryption identity with existing Secret support.
- Ingress, Gateway API, External Secrets, dual-stack, and NetworkPolicy.
- Optional native Prometheus Service, ServiceMonitor, and PrometheusRule.
- Restricted non-root runtime with no service-account token.

## Installation

Configure a dedicated HTTPS origin before enrolling any passkeys:

```yaml
server:
  publicUrl: https://id.example.com
bootstrap:
  username: administrator
  email: administrator@example.com
  firstName: Identity
  lastName: Administrator
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: id.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: identity-tls
      hosts: [id.example.com]
```

Install with `helm install identity helmforge/pocket-id -n identity --create-namespace -f values.yaml`. See
[onboarding](docs/onboarding.md) before the first login.

## Architecture and authentication

The initializer copies the unchanged static application binary from the official image and starts it with native HTTP
and actor listeners bound to loopback. It uses the native initial-signup API, verifies the administrator role and closed
setup endpoint, then stops before the main container starts. It never changes an existing user or generates another
access token during upgrades.

Generate the native single-use, one-hour login link when ready to enroll a passkey. Treat its command output as a
credential. No initial password is generated because Pocket ID authenticates with passkeys.

Setting `bootstrap.enabled: false` skips account creation, but still checks privately that the database is initialized.
An uninitialized database fails before public exposure.

## Persistence and recovery

SQLite is the default. Select `database.type: postgresql` and `postgresql.enabled: true` to install the HelmForge
PostgreSQL dependency, or supply external connection components and a password Secret. External connections default to
certificate and hostname verification. The chart prepares required extensions on a fresh bundled database and checks
prerequisites before native migrations. See [database preparation](docs/database.md) before changing engines or
upgrading an existing database.

The default 5 GiB retained PVC stores SQLite and uploads. The application encryption key is generated once in a retained
Secret or supplied through `encryption.existingSecret` and `encryption.secretKey`. Back up the complete data directory
and original key together. The key protects sensitive application fields, including signing material; it does not
encrypt the entire SQLite database file. Keep a consistent, quiesced snapshot rather than copying a live database alone.

Passkeys depend on the HTTPS relying-party origin. Changing `server.publicUrl` can invalidate existing credentials;
treat origin changes as an identity migration. See [recovery](docs/recovery.md) for consistent backups, fresh-volume
restoration and operator access.

## Security and availability

- Exactly one application replica and Recreate upgrades, with planned downtime.
- UID/GID 1000, read-only root filesystem, dropped Linux capabilities and no mounted service account token.
- HTTP probes on `/healthz`; actor listener is private and is not exposed by a Service.
- NetworkPolicy enables ingress control and isolates egress to DNS plus explicitly configured destinations.
- Insecure OIDC callback URLs, query-argument logging, downgrade allowance, analytics and version checks are disabled.
- Ingress, Gateway API, dual-stack Services and External Secrets Operator use the standard HelmForge contracts.

Do not claim high availability by raising the replica count. The pinned upstream release does not expose its unfinished
HA mode as an environment configuration option.

## Configuration

The main runtime contracts are explicit and independently configurable:

| Value | Default | Purpose |
| --- | ---: | --- |
| `server.publicUrl` | `https://id.example.com` | HTTPS issuer and passkey relying-party origin |
| `server.port` | `1411` | Native application listener |
| `service.port` | `1411` | Cluster-facing Service port |
| `database.type` | `sqlite` | SQLite or PostgreSQL backend |
| `postgresql.enabled` | `false` | HelmForge PostgreSQL 2.1.1 dependency |
| `persistence.size` | `5Gi` | SQLite and uploads workspace capacity |
| `encryption.existingSecret` | `""` | Externally managed stable encryption identity |
| `bootstrap.enabled` | `true` | Create the first administrator privately |
| `metrics.enabled` | `false` | Native Prometheus listener and Service |
| `networkPolicy.enabled` | `true` | Application ingress and egress isolation |

Every value is documented in [values.yaml](values.yaml) and constrained by
[values.schema.json](values.schema.json). Keep `server.publicUrl` on its final
HTTPS origin before enrolling passkeys.

## Examples

- [Production SQLite](examples/production-sqlite.yaml)
- [Bundled PostgreSQL](examples/bundled-postgresql.yaml)
- [External PostgreSQL](examples/external-postgresql.yaml)
- [Database preparation](docs/database.md)
- [Monitoring](docs/monitoring.md)

## Monitoring

Enable `metrics.enabled` for the native Prometheus exporter on its own private Service. Optional ServiceMonitor and
PrometheusRule resources integrate with Prometheus Operator. The bootstrap process never opens that listener. See
[monitoring](docs/monitoring.md) for selectors, network access and alert boundaries.

## Validation

The complete HelmForge gate covers 23 layers, 13 runtime scenarios and 25 Helm unit tests. Coverage includes native
bootstrap, browser passkey enrollment/login, OIDC code flow with PKCE, bundled and external PostgreSQL, real Prometheus
scraping, External Secrets and fresh-volume identity recovery. Runtime tests use the owned local k3d cluster;
production capacity and external relying-party availability remain deployment-specific.

## Security Scan: `pocket-id`

| Framework | Score       |
| --------- | ----------- |
| Overall   | **100.00%** |
| MITRE     | **100.00%** |
| NSA       | **100.00%** |
| SOC2      | **100.00%** |

Kubescape 4.0.13, default rendered manifests, 2026-09-10. No findings and no control suppressions. This configuration
scan does not replace image vulnerability management or application security review.

## Troubleshooting

Inspect init containers separately because bootstrap and database admission
finish before the application container starts:

```bash
kubectl -n identity get pod,service,pvc
kubectl -n identity describe pod -l app.kubernetes.io/instance=identity
kubectl -n identity logs deployment/identity-pocket-id -c bootstrap
kubectl -n identity logs deployment/identity-pocket-id -c pocket-id
kubectl -n identity get events --sort-by=.lastTimestamp
```

For PostgreSQL deployments, inspect the database init containers before the
bootstrap container because either can stop initialization:

```bash
kubectl -n identity logs deployment/identity-pocket-id -c database-url
kubectl -n identity logs deployment/identity-pocket-id -c database-admission
```

For setup failures, verify the final HTTPS `server.publicUrl`, encryption
Secret key, writable retained storage, and PostgreSQL extensions and schema
permissions. For login failures after an origin change, follow the documented
[recovery procedure](docs/recovery.md) instead of rotating encryption state.

## Sources

- [Pocket ID v2.14.0](https://github.com/pocket-id/pocket-id/tree/v2.14.0)
- [Official configuration documentation](https://pocket-id.org/docs/configuration/environment-variables)

## Gateway API contract

Use `gatewayAPI.enabled` and `gatewayAPI.httpRoutes[]`. Set each route's `parentRefs` to a shared Gateway that allows
this namespace, and configure its HTTPS listener and public hostname. Routes accept labels, annotations and rules
with matches, filters and optional backend references; omitted backends target this chart's application Service.
Ingress and HTTPRoute resources can coexist. Verify controller conditions and public traffic before production use.
See the [Gateway API documentation](https://gateway-api.sigs.k8s.io/).
