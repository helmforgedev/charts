# Architecture

## How Cloudflare Tunnel Works

Cloudflare Tunnel (`cloudflared`) creates secure, outbound-only connections from your Kubernetes cluster to Cloudflare's edge network. No inbound ports need to be opened — the daemon initiates all connections.

```
                  ┌──────────────────────────────┐
                  │    Cloudflare Edge Network    │
 Internet ──────▶ │  (TLS, DDoS, WAF, CDN)       │
                  │                               │
                  └──────────┬───────────────────┘
                             │ Outbound connection
                             │ (initiated by cloudflared)
                  ┌──────────▼───────────────────┐
                  │   Kubernetes Cluster          │
                  │                               │
                  │  ┌─────────────┐              │
                  │  │ cloudflared │──▶ svc-a:80  │
                  │  │  (2 pods)   │──▶ svc-b:443 │
                  │  └─────────────┘              │
                  │                               │
                  └──────────────────────────────┘
```

## Key Concepts

### Remotely-Managed Tunnel

This chart uses the **remotely-managed** tunnel model. All routing configuration (public hostnames, private networks) is managed through the Cloudflare dashboard, not through local config files. The chart only needs the tunnel token.

### High Availability

The chart deploys 2 replicas by default with a PodDisruptionBudget. Each replica establishes independent connections to Cloudflare's edge. Important notes:

- **Do not use HPA** — downscaling breaks active connections
- Use `topologySpreadConstraints` to spread replicas across nodes
- The PDB ensures at least 1 replica survives during rolling updates

### Metrics

The `/ready` endpoint on port 2000 serves as both the health check and the Prometheus metrics endpoint. The chart optionally creates a ServiceMonitor for Prometheus Operator integration.

## Comparison with Ingress Controllers

| Feature | Cloudflare Tunnel | Ingress Controller |
|---------|------------------|--------------------|
| Public IP required | No | Yes |
| Firewall ports | None | 80, 443 |
| TLS certificates | Managed by Cloudflare | cert-manager or manual |
| DDoS protection | Built-in | External |
| Load balancer cost | None | Cloud LB cost |
| Provider lock-in | Cloudflare | None |

<!-- @AI-METADATA
@description: Architecture overview of the Cloudflare Tunnel (cloudflared) Helm chart
@type: chart-docs
@chart: cloudflared
@path: charts/cloudflared/docs/architecture.md
@date: 2026-03-23
@relations:
  - charts/cloudflared/README.md
  - charts/cloudflared/values.yaml
-->
