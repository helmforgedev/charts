# Cloudflare Tunnel (cloudflared) Helm Chart

Deploy [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) on Kubernetes using the official
[cloudflare/cloudflared](https://hub.docker.com/r/cloudflare/cloudflared) Docker image.
Secure, outbound-only connections between your cluster and Cloudflare's network require no open ports or public IP.

## Features

- **Zero-trust networking** — no inbound firewall rules needed
- **Remotely-managed** — configure routes in the Cloudflare dashboard
- **High availability** — 2 replicas with PodDisruptionBudget by default
- **Prometheus metrics** — `/ready` and `/metrics` on port 2000
- **ServiceMonitor** — optional Prometheus Operator integration
- **Existing secrets** — bring your own Secret for the tunnel token
- **External Secrets** — optional External Secrets Operator integration for tunnel tokens
- **Quick tunnel mode** — optional ephemeral mode for demos and smoke tests

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install cloudflared helmforge/cloudflared -f values.yaml
```

**OCI registry:**

```bash
helm install cloudflared oci://ghcr.io/helmforgedev/helm/cloudflared -f values.yaml
```

## Quick Start

1. Create a tunnel in the [Cloudflare dashboard](https://one.dash.cloudflare.com) under **Networks → Tunnels**.
2. Copy the tunnel token.
3. Deploy:

```yaml
# values.yaml
tunnel:
  token: "eyJhIjoiY2Y..."
```

1. Configure public hostnames in the dashboard to route traffic to your Kubernetes services (for example, `http://my-service.default.svc:80`).

## Using an Existing Secret

```yaml
tunnel:
  existingSecret: my-tunnel-secret
  existingSecretKey: token
```

Create the secret beforehand:

```bash
kubectl create secret generic my-tunnel-secret \
  --from-literal=token=eyJhIjoiY2Y...
```

## External Secrets

When your cluster already runs External Secrets Operator, render an `ExternalSecret`
for the tunnel token and point the Deployment at the generated Kubernetes Secret:

```yaml
tunnel:
  existingSecret: cloudflared-tunnel-token

externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
    kind: ClusterSecretStore
  data:
    - secretKey: token
      remoteRef:
        key: cloudflared/tunnel
        property: token
```

## Quick Tunnel Mode

Quick tunnel mode runs an ephemeral tunnel without a Cloudflare-managed tunnel token.
Use it for demos and smoke tests only; production deployments should use `tunnel.token` or `tunnel.existingSecret`.

```yaml
tunnel:
  quickTunnel:
    enabled: true
```

## Production Example

```yaml
tunnel:
  existingSecret: cloudflare-tunnel

replicaCount: 2

pdb:
  enabled: true
  minAvailable: 1

resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    memory: 128Mi

serviceMonitor:
  enabled: true
  labels:
    release: prometheus

topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: cloudflared
```

## Default Values

| Key | Default | Description |
|-----|---------|-------------|
| `tunnel.token` | `""` | Tunnel token from Cloudflare dashboard |
| `tunnel.existingSecret` | `""` | Existing secret with tunnel token |
| `tunnel.existingSecretKey` | `token` | Key in the existing secret |
| `tunnel.quickTunnel.enabled` | `false` | Enable ephemeral quick tunnel mode |
| `tunnel.quickTunnel.helloWorld` | `true` | Use cloudflared's built-in hello-world origin |
| `tunnel.quickTunnel.url` | `http://localhost:8080` | Origin URL for quick tunnel URL mode |
| `externalSecrets.enabled` | `false` | Render an ExternalSecret for the tunnel token |
| `externalSecrets.secretStoreRef.name` | `""` | SecretStore or ClusterSecretStore name |
| `externalSecrets.secretStoreRef.kind` | `SecretStore` | Secret store kind |
| `externalSecrets.data` | `[]` | ExternalSecret data mappings |
| `replicaCount` | `2` | Number of replicas |
| `cloudflared.logLevel` | `info` | Log level |
| `cloudflared.noAutoupdate` | `true` | Disable auto-update |
| `cloudflared.metricsPort` | `2000` | Metrics listen port |
| `cloudflared.extraArgs` | `[]` | Extra cloudflared arguments |
| `pdb.enabled` | `true` | Create PodDisruptionBudget |
| `pdb.minAvailable` | `1` | Min available during disruption |
| `metrics.enabled` | `true` | Expose metrics service |
| `serviceMonitor.enabled` | `false` | Create Prometheus ServiceMonitor |
| `service.port` | `2000` | Metrics service port |
| `service.ipFamilyPolicy` | `""` | Service IP family policy |
| `service.ipFamilies` | `[]` | Ordered list of Service IP families |
| `resources.requests.cpu` | `50m` | Default CPU request |
| `resources.requests.memory` | `64Mi` | Default memory request |
| `resources.limits.cpu` | `250m` | Default CPU limit |
| `resources.limits.memory` | `128Mi` | Default memory limit |
| `securityContext.runAsUser` | `65532` | Non-root container user |

## Important Notes

- **Do not use HPA** — downscaling terminates active tunnel connections
- **Routing is dashboard-managed** — this chart does not configure ingress rules; use the Cloudflare dashboard to map public hostnames to internal services
- **No ingress template** — cloudflared replaces traditional ingress controllers

## More Information

- [Cloudflare Tunnel documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [Kubernetes deployment guide](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/deploy-tunnels/deployment-guides/kubernetes/)
- [Architecture overview](docs/architecture.md)

<!-- @AI-METADATA
@description: README for the Cloudflare Tunnel (cloudflared) Helm chart
@type: chart-readme
@chart: cloudflared
@path: charts/cloudflared/README.md
@date: 2026-03-23
@relations:
  - charts/cloudflared/values.yaml
  - charts/cloudflared/docs/architecture.md
-->
