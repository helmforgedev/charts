# JupyterHub

JupyterHub provides multi-user notebook servers for teams, classrooms, and
research platforms.

This HelmForge chart deploys a JupyterHub Hub and configurable-http-proxy pair
with a managed proxy token Secret, KubeSpawner configuration, namespaced RBAC for
user pods, optional user PVCs, Gateway API, Ingress, dual-stack Service,
NetworkPolicy, ExternalSecret, ServiceMonitor, PodDisruptionBudget, schema, and
Helm tests.

NetworkPolicy supports `networkPolicy.extraEgress` for appending Hub egress
rules without replacing the default DNS, HTTPS, same-namespace, and
`networkPolicy.hub.egress` rules.

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm install jupyterhub helmforge/jupyterhub
```

## Proxy Token

The chart generates a proxy token by default. For GitOps-managed credentials,
set `proxy.existingSecret` and optionally render an `ExternalSecret`.

## Production Notes

Keep the default SQLite Hub database to one Hub replica. For larger deployments,
configure an external database with `hub.extraConfig` and manage it with the
HelmForge PostgreSQL chart.
Set `c.JupyterHub.db_url` in `hub.extraConfig` before increasing
`hub.replicaCount` above `1`.
When running multiple Hub replicas, disable Hub persistence or use multi-writer
storage; `ReadWriteOnce` and `ReadWriteOncePod` PVCs are intentionally rejected
for HA Hub deployments.
If Hub persistence is disabled for HA, set `hub.cookieSecret.existingSecret` so
all Hub replicas read the same `jupyterhub_cookie_secret` file and can decrypt
each other's login cookies.
The chart runs configurable-http-proxy separately from the Hub and defaults
`hub.cleanupServers=false`, so notebook pods are not stopped during normal Hub
rollouts or node drains.
Prometheus metrics stay authenticated by default. If you enable a
ServiceMonitor, set `metrics.authenticatePrometheus=false` only for private
scrape paths, or explicitly set
`metrics.allowPublicUnauthenticatedPrometheus=true` when public exposure should
also allow anonymous `/hub/metrics`.

## Single-User Image

```yaml
singleuser:
  image:
    name: quay.io/jupyter/scipy-notebook
    tag: "2026-05-26"
```

## Profiles

```yaml
singleuser:
  profiles:
    - display_name: Standard
      slug: standard
      default: true
      kubespawner_override:
        cpu_limit: 1
        mem_limit: 2G
```

## Security Scan: `jupyterhub`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **81.666664%** |

> Security posture acceptable with non-root Hub and proxy containers, restricted single-user pod defaults, explicit public exposure guardrails, and operator-controlled RBAC for KubeSpawner.

## Documentation

- [Design](./DESIGN.md)
- [Production guide](./docs/production.md)
- [Networking](./docs/networking.md)
- [External Secrets](./docs/external-secrets.md)
- [Production values example](./examples/production.yaml)
- [Gateway API example](./examples/gateway.yaml)
- [External Secrets example](./examples/external-secrets.yaml)
