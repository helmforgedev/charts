# Cloudflare Tunnel (cloudflared) Helm Chart

Deploy [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) on Kubernetes using the official
[cloudflare/cloudflared](https://hub.docker.com/r/cloudflare/cloudflared) Docker image.
Secure, outbound-only connections between your cluster and Cloudflare's network require no open ports or public IP.

## Features

- **Zero-trust networking** — no inbound firewall rules needed
- **Remotely-managed** — configure routes in the Cloudflare dashboard
- **Quick tunnel default** — installable demo and smoke-test mode without a token
- **High availability ready** — production values can enable 2+ replicas with PodDisruptionBudget
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

Default installs run an ephemeral quick tunnel for demos and smoke tests. For a
managed Cloudflare Tunnel, create a tunnel in the
[Cloudflare dashboard](https://one.dash.cloudflare.com) under **Networks → Tunnels**,
copy the tunnel token, and deploy:

```yaml
# values.yaml
tunnel:
  quickTunnel:
    enabled: false
  token: "eyJhIjoiY2Y..."
```

Then configure public hostnames in the dashboard to route traffic to your
Kubernetes services (for example, `http://my-service.default.svc:80`).

## Using an Existing Secret

```yaml
tunnel:
  quickTunnel:
    enabled: false
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
  quickTunnel:
    enabled: false
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
It is enabled by default for tokenless installs. Use it for demos and smoke
tests only; production deployments should set `tunnel.quickTunnel.enabled=false`
and use `tunnel.token` or `tunnel.existingSecret`.

```yaml
tunnel:
  quickTunnel:
    enabled: true
```

## Production Example

```yaml
tunnel:
  quickTunnel:
    enabled: false
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
| `tunnel.quickTunnel.enabled` | `true` | Enable ephemeral quick tunnel mode for demos and smoke tests |
| `tunnel.quickTunnel.helloWorld` | `true` | Use cloudflared's built-in hello-world origin |
| `tunnel.quickTunnel.url` | `http://localhost:8080` | Origin URL for quick tunnel URL mode |
| `externalSecrets.enabled` | `false` | Render an ExternalSecret for the tunnel token |
| `externalSecrets.secretStoreRef.name` | `""` | SecretStore or ClusterSecretStore name |
| `externalSecrets.secretStoreRef.kind` | `SecretStore` | Secret store kind |
| `externalSecrets.data` | `[]` | ExternalSecret data mappings |
| `replicaCount` | `1` | Number of replicas |
| `cloudflared.logLevel` | `info` | Log level |
| `cloudflared.noAutoupdate` | `true` | Disable auto-update |
| `cloudflared.metricsPort` | `2000` | Metrics listen port |
| `cloudflared.extraArgs` | `[]` | Extra cloudflared arguments |
| `pdb.enabled` | `false` | Create PodDisruptionBudget |
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

## Security Scan

🟢 Security Scan: `cloudflared`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **87.88%** |

> ✅ Security posture acceptable.

Local details:

| Framework | Score |
|---|---|
| MITRE | 100.00% |
| NSA | 85.00% |
| SOC2 | 80.00% |

The remaining local scan findings are expected for raw chart scanning and
platform-level controls: NetworkPolicy is supplied by the platform layer, token
Secret access is intentionally scoped to the pod, and raw-template static
analysis does not fully evaluate Helm-rendered non-root defaults.

## More Information

- [Cloudflare Tunnel documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [Kubernetes deployment guide](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/deploy-tunnels/deployment-guides/kubernetes/)
- [Architecture overview](docs/architecture.md)
