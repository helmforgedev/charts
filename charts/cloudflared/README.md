# Cloudflare Tunnel (cloudflared) Helm Chart

Deploy [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) on Kubernetes using the official [cloudflare/cloudflared](https://hub.docker.com/r/cloudflare/cloudflared) Docker image. Secure, outbound-only connections between your cluster and Cloudflare's network — no open ports, no public IP required.

## Features

- **Zero-trust networking** — no inbound firewall rules needed
- **Remotely-managed** — configure routes in the Cloudflare dashboard
- **High availability** — 2 replicas with PodDisruptionBudget by default
- **Prometheus metrics** — `/ready` and `/metrics` on port 2000
- **ServiceMonitor** — optional Prometheus Operator integration
- **Existing secrets** — bring your own Secret for the tunnel token

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

4. Configure public hostnames in the dashboard to route traffic to your Kubernetes services (e.g., `http://my-service.default.svc:80`).

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
