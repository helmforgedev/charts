# Architecture

## How Cloudflare Tunnel Works

Cloudflare Tunnel (`cloudflared`) creates secure, outbound-only connections from your Kubernetes cluster to Cloudflare's edge network.
No inbound ports need to be opened because the daemon initiates all connections.

```text
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

This chart uses the **remotely-managed** tunnel model.
All routing configuration, including public hostnames and private networks, is managed through the Cloudflare dashboard instead of local config files.
The chart only needs the tunnel token.

### Default and High Availability

The default chart install uses a single quick tunnel so local smoke tests can
run without a Cloudflare token. Production managed tunnels should set
`tunnel.quickTunnel.enabled=false`, configure `tunnel.existingSecret` or
`tunnel.token`, use 2 or more replicas, and enable a PodDisruptionBudget. Each
managed-tunnel replica establishes independent connections to Cloudflare's edge.
Important notes:

- **Do not use HPA** — downscaling breaks active connections
- Use `topologySpreadConstraints` to spread replicas across nodes
- Enable the PDB for multi-replica production deployments so at least 1 replica survives during voluntary disruptions

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
