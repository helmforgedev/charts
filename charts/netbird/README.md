# NetBird Helm Chart

Deploy [NetBird](https://github.com/netbirdio/netbird), a self-hosted WireGuard overlay network control plane with device management, identity-aware access, and peer coordination.

This chart packages the current upstream combined architecture:

- `netbirdio/netbird-server:0.74.4` for the management API, gRPC endpoint, signal, relay, metrics, health, and UDP STUN service
- `netbirdio/dashboard:v2.90.3` for the web UI
- a generated or externally supplied `config.yaml`
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

## Production notes

NetBird peers need a stable public endpoint. Expose:

- TCP `443` at your reverse proxy or ingress controller for dashboard, API, gRPC, signal, and relay traffic
- UDP `3478` for STUN

The chart listens on HTTP inside Kubernetes and expects TLS termination at your ingress, gateway, load balancer, or external reverse proxy. Ensure your proxy supports HTTP/2 or gRPC for the server endpoint.

GeoLite database updates are disabled by default for deterministic Kubernetes startup. Set `server.disableGeoliteUpdate=false` only when your cluster allows the server pod to download the upstream databases during boot. Server health probes are also opt-in with `server.probes.enabled=true` because a fresh server can spend several minutes initializing geolocation data before opening the health endpoint.

Use `server.config.existingSecret` when you need to provide a full upstream `config.yaml` directly. Otherwise the chart renders one from values and stores it in a Kubernetes Secret.

## Storage

The default store engine is `sqlite`, so the server Deployment defaults to one replica and uses a `Recreate` strategy. For horizontal server scaling, configure an external `postgres` or `mysql` store and set `server.replicaCount` above one.

## External secrets

Use `externalSecrets.items[]` to synchronize sensitive values such as `config.yaml`, owner bootstrap credentials, OIDC client secrets, or database credentials from an external secret store.

## Security Scan

Local security scan:

```text
Image: netbirdio/netbird-server:0.74.4
Image: netbirdio/dashboard:v2.90.3
Scanner: pending local repository security scan
Result: pending
```

The chart is designed for the HelmForge security scan workflow. Local scan
evidence must be refreshed before merge with the repository security tooling and
then pasted into this section if required by the release checklist.

## Validation

```bash
make validate-chart CHART=netbird
```

The HelmForge gate runs dependency checks, lint, template scenarios, unit tests, kubeconform, Artifact Hub lint, and k3d behavioral validation.
