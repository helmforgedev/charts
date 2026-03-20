# Keycloak

Keycloak for Kubernetes with explicit `dev` and `production` modes, external database modeling for real deployments, and a clear separation between public traffic and the management interface.

## Install

```bash
helm install keycloak oci://ghcr.io/mberlofa/helm/keycloak -f values.yaml
```

## Supported modes

| Mode | When to use | Document |
|------|-------------|----------|
| `dev` | local testing, bootstrap validation, temporary environments | [docs/dev.md](docs/dev.md) |
| `production` | reverse-proxy deployments with an external database | [docs/production.md](docs/production.md) |

## What this chart covers

- explicit `dev` and `production` runtime modes
- official `quay.io/keycloak/keycloak` image
- bootstrap admin credentials through generated secret or `existingSecret`
- external database as the production path
- explicit hostname and proxy configuration
- separate management service for health and metrics
- optional realm import through `/opt/keycloak/data/import`
- optional provider and theme mounts
- optional separate ingresses for public and admin traffic
- optional `ServiceMonitor`

## How to choose the mode

- use `dev` when you need quick startup and disposable local behavior
- use `production` when you need external URLs, reverse proxy correctness, and an external database

Recommended reading before installation:

- [Dev Mode](docs/dev.md)
- [Production Mode](docs/production.md)

## Official product references

- Keycloak production configuration: https://www.keycloak.org/server/configuration-production
- Keycloak hostname configuration: https://www.keycloak.org/server/hostname
- Keycloak caching and transport stacks: https://www.keycloak.org/server/caching
- Keycloak general configuration: https://www.keycloak.org/server/configuration

## Operational direction

- `production` is the normal path for real environments
- production expects a reverse proxy or ingress in front of Keycloak
- the management interface is kept separate and must not be exposed through the public or admin ingress
- multi-replica runtime is supported, but it must be treated as a cache/discovery concern and not just a Deployment scaling flag

## Quick start

Minimal local example:

```yaml
mode: dev
```

Production example:

```yaml
mode: production

hostname:
  hostname: https://sso.example.com

database:
  vendor: postgres
  host: postgresql-rw.default.svc
  name: keycloak
  username: keycloak
  existingSecret: keycloak-db
```

## Best practices

### Security

- use `mode: production` for all real environments
- prefer `admin.existingSecret` and `database.existingSecret`
- keep the management service internal
- restrict admin exposure at the reverse proxy layer when using a dedicated admin hostname

### Reverse proxy and hostname

- always set `hostname.hostname` in production mode
- set `hostname.admin` when the admin console should live on a separate host
- align `proxy.headers` with your ingress or reverse proxy behavior
- use the public ingress for user-facing traffic and a separate admin ingress when the admin console should sit behind a different ingress class or internal load balancer

### Database and runtime

- treat the external database as part of the critical-path design
- prefer PostgreSQL for production examples and guidance
- do not use `dev` mode as a hidden production shortcut

### Realm import and extensions

- use realm import for bootstrap and lower-environment seeding
- do not treat startup import as a full reconciliation control plane
- mount providers and themes explicitly so restart behavior stays predictable

## Production notes

- production mode fails fast when hostname or database configuration is missing
- management health and metrics stay on the management service
- public and admin ingresses both route only to the application service
- the admin ingress exists to separate exposure policy, hostname, and ingress class from the public ingress
- if `replicaCount > 1`, keep cache and cluster expectations explicit in the deployment plan

## Main values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mode` | `dev` or `production` | `dev` |
| `image.repository` | Keycloak image repository | `quay.io/keycloak/keycloak` |
| `image.tag` | Keycloak image tag | `26.5.5` |
| `admin.existingSecret` | Existing secret for bootstrap admin credentials | `""` |
| `http.port` | Application HTTP port | `8080` |
| `http.managementPort` | Management port for health and metrics | `9000` |
| `http.relativePath` | Relative HTTP path | `/` |
| `hostname.hostname` | Public hostname or URL | `""` |
| `hostname.admin` | Dedicated admin hostname or URL | `""` |
| `proxy.headers` | Proxy headers mode | `xforwarded` |
| `database.vendor` | Database vendor in production mode | `postgres` |
| `database.host` | Database host | `""` |
| `database.name` | Database name | `keycloak` |
| `database.username` | Database username | `keycloak` |
| `database.existingSecret` | Existing secret for database password | `""` |
| `replicaCount` | Number of Keycloak replicas | `1` |
| `cache.stack` | Cache stack for multi-replica production | `jdbc-ping` |
| `realmImport.enabled` | Enable startup realm import | `false` |
| `ingress.public.enabled` | Enable public ingress for Keycloak | `false` |
| `ingress.public.ingressClassName` | Public ingress class name | `traefik` |
| `ingress.admin.enabled` | Enable separate admin ingress | `false` |
| `ingress.admin.ingressClassName` | Admin ingress class name | `traefik` |
| `metrics.enabled` | Enable Keycloak metrics | `false` |
| `metrics.serviceMonitor.enabled` | Enable ServiceMonitor | `false` |
| `networkPolicy.enabled` | Enable NetworkPolicy | `false` |

## CI scenarios

The `ci/` scenarios validate the main chart behaviors:

- `minimal.yaml`
- `external-db.yaml`
- `realm-import.yaml`
- `ingress.yaml`
- `metrics.yaml`
- `multi-replica.yaml`

## Examples

See `examples/`:

- `minimal.yaml`
- `external-db-ha.yaml`
- `realm-import.yaml`
