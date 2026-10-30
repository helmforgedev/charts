# NetBird Helm Chart

Deploy [NetBird](https://github.com/netbirdio/netbird), a self-hosted WireGuard overlay network control plane with device management, identity-aware access, and peer coordination.

This chart packages the current upstream combined architecture:

- `netbirdio/netbird-server:0.81.5` for the management API, gRPC endpoint, signal, relay, metrics, health, and UDP STUN service
- `netbirdio/dashboard:v2.90.10` for the web UI
- a generated or externally supplied `config.yaml`
- HelmForge PostgreSQL subchart as the default production store
- optional persistent storage under `/var/lib/netbird`
- dashboard OIDC environment derived from chart values
- Ingress and Gateway API HTTPRoute support for HTTP/gRPC front doors
- UDP `3478` Service exposure for STUN
- External Secrets Operator integration for production secret delivery
- NetworkPolicy, PDB, dual-stack service fields, and Helm tests

## Install

```bash
helm repo add helmforge https://helmforge.dev/charts
helm repo update
helm install netbird helmforge/netbird --namespace netbird --create-namespace
```

For production, set at least a real public URL and a strong auth secret:

```bash
helm upgrade --install netbird helmforge/netbird \
  --namespace netbird --create-namespace \
  --set server.publicUrl=https://netbird.example.com \
  --set server.auth.issuer=https://netbird.example.com/oauth2 \
  --set server.authSecret="$(openssl rand -hex 32)"
```

The v1 chart defaults to PostgreSQL-backed storage through the HelmForge
PostgreSQL subchart. For disposable or single-node lab installs, explicitly set:

```yaml
database:
  mode: sqlite
postgresql:
  enabled: false
```

## Configuration

The values contract is validated by `values.schema.json`. Application listeners and Kubernetes Service ports are
separate: change `server.containerPorts.*` or `dashboard.containerPorts.http` to move the actual process listener, and
change the corresponding `*.service.*Port` only to change the Service-facing port. Services use named target ports so
both contracts remain synchronized.

| Parameter | Default | Purpose |
|---|---:|---|
| `server.replicaCount` | `1` | Combined server replicas; SQLite is restricted to one. |
| `server.publicUrl` | `https://netbird.example.com` | Stable public URL advertised to peers and the dashboard. |
| `server.authSecret` | `change-me-in-production` | Relay authentication secret; replace before production. |
| `server.containerPorts.http` | `80` | Real combined HTTP/gRPC process listener. |
| `server.containerPorts.stun` | `3478` | Real UDP STUN process listener. |
| `server.containerPorts.metrics` | `9090` | Real Prometheus metrics listener. |
| `server.containerPorts.health` | `9000` | Real server health listener. |
| `server.service.httpPort` | `80` | Server Service HTTP/gRPC port. |
| `server.service.stunPort` | `3478` | Server Service UDP STUN port. |
| `server.probes.enabled` | `false` | Enable server startup, liveness, and readiness probes. |
| `server.config.existingSecret` | `""` | Mount an operator-owned upstream `config.yaml`. |
| `server.store.encryptionKey` | `""` | Stable base64 32-byte key; generated and preserved when empty. |
| `dashboard.enabled` | `true` | Deploy the NetBird dashboard. |
| `dashboard.containerPorts.http` | `80` | Real dashboard nginx listener. |
| `dashboard.service.port` | `80` | Dashboard Service port. |
| `database.mode` | `auto` | Select `auto`, `sqlite`, `postgresql`, or `external`. |
| `database.external.engine` | `postgres` | External database engine: PostgreSQL or MySQL. |
| `postgresql.enabled` | `true` | Deploy the HelmForge PostgreSQL dependency. |
| `persistence.enabled` | `true` | Persist `/var/lib/netbird`. |
| `persistence.emptyDirSizeLimit` | `1Gi` | Bound disposable server data when persistence is off. |
| `resources.requests.cpu` | `50m` | Default request for both application containers. |
| `resources.requests.memory` | `64Mi` | Default memory request for both application containers. |
| `resources.limits.cpu` | `500m` | Default CPU limit for both application containers. |
| `resources.limits.memory` | `256Mi` | Default memory limit for both application containers. |
| `serviceAccount.automountServiceAccountToken` | `false` | Keep Kubernetes API credentials out of pods. |
| `networkPolicy.enabled` | `false` | Isolate inbound traffic; egress activates with extra rules. |
| `networkPolicy.stunIngressFrom` | `[]` | Optional UDP STUN peers, separate from HTTP-facing ingress peers. |
| `pdb.enabled` | `false` | Render disruption budgets for server and dashboard. |
| `externalSecrets.enabled` | `false` | Render External Secrets Operator resources. |

Inspect the complete contract before changing advanced values:

```bash
helm show values helmforge/netbird
```

## Architecture

The chart runs the upstream combined server and dashboard as separate Deployments. The server configuration is Secret
backed, PostgreSQL is the production data store by default, and HTTP/gRPC plus dashboard routes can be exposed through
Ingress or Gateway API. UDP STUN is always a separate Service concern. See [DESIGN.md](DESIGN.md) for boundaries and
decisions.

## Examples and guides

- [Production values](examples/production.yaml)
- [Simple installation](examples/simple.yaml)
- [Ingress exposure](examples/ingress.yaml)
- [Gateway API exposure](examples/gateway-api.yaml)
- [Secure existing-Secret setup](examples/secured.yaml)
- [Exposure guide](docs/exposure.md)
- [Storage and database guide](docs/storage.md)
- [Operations and recovery guide](docs/operations.md)
- [Security guide](docs/security.md)

## Production notes

NetBird peers need a stable public endpoint. Expose:

- TCP `443` at your reverse proxy or ingress controller for dashboard, API, gRPC, signal, and relay traffic
- UDP `3478` for STUN

The chart listens on HTTP inside Kubernetes and expects TLS termination at your ingress,
gateway, load balancer, or external reverse proxy. Ensure your proxy supports HTTP/2 or
gRPC for the server endpoint.

GeoLite database updates are disabled by default for deterministic Kubernetes startup.
Set `server.disableGeoliteUpdate=false` only when your cluster allows the server pod to
download the upstream databases during boot. Server health probes are also opt-in with
`server.probes.enabled=true` because a fresh server can spend several minutes initializing
geolocation data before opening the health endpoint.

Use `server.config.existingSecret` when you need to provide a full upstream `config.yaml` directly. Otherwise the chart renders one from values and stores it in a Kubernetes Secret.

With `server.config.existingSecret`, the chart uses your configuration unchanged.
In the supplied config's `server.auth.dashboardRedirectURIs`, omit `:443` from
HTTPS URLs and `:80` from HTTP URLs to match browser origins. Updating only the
Secret data does not change the Deployment's config checksum or trigger a
rollout, so restart the server Deployment after updating the Secret to load
the new configuration.

## Embedded identity provider

The default dashboard authentication settings match the identity provider
embedded in `netbird-server`:

```yaml
server:
  publicUrl: https://netbird.example.com
  auth:
    issuer: https://netbird.example.com/oauth2

dashboard:
  auth:
    clientId: netbird-dashboard
    audience: netbird-dashboard
    supportedScopes: openid profile email groups
    redirectUri: /nb-auth
    silentRedirectUri: /nb-silent-auth
```

The generated server configuration allows the corresponding absolute callback
URLs below `server.publicUrl`. Keep the dashboard and server on the same public
hostname when using the embedded provider. Override all dashboard auth values
when integrating an external OIDC provider.

An explicit default port in `server.publicUrl` (`:443` for HTTPS or `:80` for
HTTP) is omitted from the generated dashboard callback URLs to match browser
origins. The public URL remains unchanged for the server's exposed address.
For chart-managed configuration, upgrading from chart `1.0.12` updates the
server pod's config checksum and automatically restarts it to load the
corrected callbacks. The dashboard appends `dashboard.auth.redirectUri` and
`dashboard.auth.silentRedirectUri` to `window.location.origin`, so these values
must be relative paths. Replace any absolute callback URL overrides with
`/nb-auth` and `/nb-silent-auth`, respectively, when using the embedded provider.

## Storage

The default store mode is `auto`, which selects the PostgreSQL subchart unless
an external database is configured. This follows upstream guidance that
PostgreSQL is the production store for concurrent access and high availability.

Use `database.mode=external` with `database.external.engine=postgres` or `mysql`
when your platform owns the database. MySQL is supported as an external database
because upstream supports it, but this chart does not add a MySQL subchart in v1;
PostgreSQL is the recommended bundled production path.

SQLite remains available for lab installs with `database.mode=sqlite` and
`postgresql.enabled=false`. Keep `server.replicaCount: 1` in sqlite mode.

## External secrets

Use `externalSecrets.items[]` to synchronize sensitive values such as `config.yaml`, owner bootstrap credentials, OIDC client secrets, or database credentials from an external secret store.

### Security Scan: `netbird`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **89.898994%** |

Rendered-manifest scan using Kubescape 4.0.13.

The local scan reported no critical failures and an overall score above the
repository security gate. Remaining findings are tracked as hardening trade-offs
for optional NetworkPolicy enablement, upstream dashboard startup model, and
operator-owned resource limit tuning across the database-backed topology.

## Upgrade to 0.81.5

NetBird `0.81.5` includes the `0.81.4` security update that distrusts
compromised eMudhra CA keys across management, signal, relay, proxy, and client
components. The `0.81.5` release also includes client SSH session hardening;
this chart deploys the server components only, so upgrade peer clients
separately to receive those client fixes. No chart configuration or schema
changes are required. Review the
[0.81.4 release notes](https://github.com/netbirdio/netbird/releases/tag/v0.81.4)
and [0.81.5 release notes](https://github.com/netbirdio/netbird/releases/tag/v0.81.5).

## Upgrade to 0.80.0

NetBird `0.80.0` strengthens account boundaries for agent-network gateways and
proxy clusters, rejects IdP redirects, revokes embedded IdP sessions after
password changes, and adds upload and reverse-proxy rate limiting. Management
also splits its store by table and includes fixes for group-resource validation,
relay disconnect notifications and forwarded client addresses. Review the
[0.80.0 release](https://github.com/netbirdio/netbird/releases/tag/v0.80.0).

The chart now generates and preserves `server.store.encryptionKey` in the
chart-managed config Secret when the value is empty. This base64-encoded 32-byte
key protects encrypted identity data and must remain stable across pod restarts
and upgrades. Existing installations that already set an explicit key keep using
it. Back up the config Secret together with the database and data volume.

An empty `reverseProxy.trustedPeers` trusts forwarded client-IP headers from
all IPv4 and IPv6 sources. Restrict it to the proxy source CIDR as seen by
NetBird Management, for example through `server.config.extraYaml`:

```yaml
server:
  config:
    extraYaml: |
      reverseProxy:
        trustedPeers:
          - 10.42.0.0/16
```

Remote debug jobs now require an explicit opt-in on the peer
(`--allow-remote-jobs` or managed `allowRemoteJobs`). The chart does not enable
remote jobs on clients. Rosenpass settings belong to the separately deployed
NetBird Reverse Proxy; `server.env` configures the combined server. Configure
`NB_PROXY_ROSENPASS=false` on that separate proxy if opting out. Test real peers,
routes and reverse-proxy services in staging before upgrading production.

Back up the configured database and `/var/lib/netbird`, then apply the new chart
defaults while preserving your explicit overrides:

```bash
helm repo update helmforge
helm upgrade netbird helmforge/netbird \
  --namespace netbird \
  --reset-then-reuse-values
```

Using `--reuse-values` alone retains the previous default image tag. Remove any
explicit `server.image.tag` override if you want the chart default `0.81.5`.

The combined server's port-9000 `/health` endpoint checks the advertised public
relay address and standalone listener list. It can return 503 in a private
installation even while the multiplexed API and relay are serving requests.
Use API authentication, OIDC discovery, relay connectivity and metrics for local
smoke checks; validate public relay reachability separately in the deployed
network. The chart's existing TCP probe policy is unchanged.

## Troubleshooting

If a rollout does not become ready, inspect both Deployments and the generated config before changing probe budgets:

```bash
kubectl get pods,svc -n netbird
kubectl logs deploy/netbird-server -n netbird
kubectl get secret netbird-config -n netbird -o jsonpath='{.data.config\.yaml}' | base64 -d
```

For browser login loops, compare the public origin with the generated dashboard redirect URIs. For peer connectivity,
verify HTTP/2 or gRPC proxying and test UDP STUN reachability independently. See the
[operations guide](docs/operations.md) for database, metrics, backup, restore, and node-drain procedures.

## Validation

```bash
make validate-chart CHART=netbird
```

The HelmForge gate runs dependency checks, lint, template scenarios, unit tests, kubeconform, Artifact Hub lint, and k3d behavioral validation.
