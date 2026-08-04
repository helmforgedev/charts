# NetBird Helm Chart

Deploy [NetBird](https://github.com/netbirdio/netbird), a self-hosted WireGuard overlay network control plane with device management, identity-aware access, and peer coordination.

This chart packages the current upstream combined architecture:

- `netbirdio/netbird-server:0.76.1` for the management API, gRPC endpoint, signal, relay, metrics, health, and UDP STUN service
- `netbirdio/dashboard:v2.90.3` for the web UI
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

## Security Scan

Local security scan:

```text
Image: netbirdio/netbird-server:0.76.1
Image: netbirdio/dashboard:v2.90.3
Scanner: Kubescape v4.0.9, frameworks MITRE, NSA, SOC2
Result: 86.86869 compliance score
```

The local scan reported no critical failures and an overall score above the
repository security gate. Remaining findings are tracked as hardening trade-offs
for optional NetworkPolicy enablement, upstream dashboard startup model, and
operator-owned resource limit tuning across the database-backed topology.

## Upgrade from 0.75.0

NetBird `0.76.1` adds management-owned LLM pricing data and requires management
and proxy components to move together. The chart's combined server image keeps
those components on the same version. It also includes client and proxy fixes.

Back up the configured database and `/var/lib/netbird`, then apply the new chart
defaults while preserving your explicit overrides:

```bash
helm repo update helmforge
helm upgrade netbird helmforge/netbird \
  --version 1.0.3 \
  --namespace netbird \
  --reset-then-reuse-values
```

Using `--reuse-values` alone retains the previous default image tag. Remove any
explicit `server.image.tag` override if you want the chart default `0.76.1`.

## Validation

```bash
make validate-chart CHART=netbird
```

The HelmForge gate runs dependency checks, lint, template scenarios, unit tests, kubeconform, Artifact Hub lint, and k3d behavioral validation.
