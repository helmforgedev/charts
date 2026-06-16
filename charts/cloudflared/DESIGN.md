# Cloudflare Tunnel Chart Design

This chart packages `cloudflared` as a fixed-replica, outbound-only tunnel
client for Kubernetes workloads that are exposed through Cloudflare Zero Trust.

## Architecture

```text
User traffic
  |
  v
Cloudflare edge
  |
  | outbound tunnel connection initiated by cloudflared
  v
Kubernetes cluster
  |
  +-- cloudflared Deployment
        |
        +-- cluster Service targets configured in the Cloudflare dashboard
```

The chart does not render Kubernetes Ingress resources. Public hostnames,
service routing, and private network routes are managed through the Cloudflare
dashboard for remotely managed tunnels.

## Design Choices

- The default workload runs a single quick tunnel so `helm install` and k3d
  smoke tests start without requiring a real Cloudflare token.
- Managed tunnels are explicit: production deployments set
  `tunnel.quickTunnel.enabled=false`, configure `tunnel.token` or
  `tunnel.existingSecret`, use 2+ replicas, and enable a PodDisruptionBudget.
- The tunnel token can be provided inline for quick starts, through an existing
  Kubernetes Secret for production, or through External Secrets Operator.
- Metrics are exposed on the cloudflared `/ready` endpoint and can be scraped
  through a Service or optional ServiceMonitor.
- Service IP family fields are optional and preserve cluster defaults unless
  explicitly set.
- Quick tunnel mode is the default for smoke tests and demos, but it is not a
  production deployment model.

## Security Model

The default container runs as a non-root user, drops Linux capabilities, blocks
privilege escalation, uses a read-only root filesystem, and relies on the
runtime default seccomp profile. The chart does not request RBAC permissions by
default because cloudflared does not need Kubernetes API access for remotely
managed tunnels.

Tunnel tokens are sensitive credentials. Production deployments should prefer
`tunnel.existingSecret` or `externalSecrets.enabled=true` over inline
`tunnel.token`, because inline values are visible in Helm release history.

## Non-Goals

- The chart does not configure Cloudflare Public Hostnames or private network
  routes.
- The chart does not manage Cloudflare API tokens.
- The chart does not use HPA. Scaling down cloudflared pods terminates active
  tunnel connections.

## Validation Focus

- Default quick tunnel deployment for CI.
- Managed tunnel deployment with an inline token for CI.
- Existing Secret consumption.
- ExternalSecret rendering with drift guard.
- Quick tunnel mode without a tunnel token.
- ServiceMonitor rendering.
- Service IP family rendering.

## Related Files

- `charts/cloudflared/README.md`
- `charts/cloudflared/docs/architecture.md`
- `charts/cloudflared/examples/production/values.yaml`
- `charts/cloudflared/examples/simple/values.yaml`
