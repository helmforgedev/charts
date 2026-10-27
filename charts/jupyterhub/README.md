# JupyterHub

JupyterHub provides multi-user notebook servers for teams, classrooms, and
research platforms. This HelmForge chart deploys a JupyterHub Hub and a
separate configurable-http-proxy workload with KubeSpawner-oriented defaults.
It includes namespaced RBAC for user pods, a managed proxy token Secret,
optional Hub and per-user storage, Ingress, Gateway API, dual-stack Services,
NetworkPolicy, External Secrets, ServiceMonitor, PodDisruptionBudget, a strict
values schema, Helm unit tests, and behavioral Kubernetes validation.

## Features

- Official, pinned JupyterHub and configurable-http-proxy images.
- A dedicated proxy Deployment so notebook servers can survive Hub restarts.
- Configurable Hub, public proxy, and proxy API listeners that change the real
  application process as well as the pod declaration.
- Named Service target ports, allowing Service ports and container listener
  ports to be configured independently.
- Secure non-root container defaults with dropped capabilities, runtime-default
  seccomp, and a read-only root filesystem.
- KubeSpawner defaults for CPU, memory, image, profile, and storage controls.
- Guardrails for unsafe public dummy authentication, unauthenticated metrics,
  SQLite high availability, single-writer Hub storage, and listener collisions.
- NetworkPolicy rules with extension points for an external database or other
  private services.
- Optional ExternalSecret and ServiceMonitor resources.

## Installation

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install jupyterhub helmforge/jupyterhub \
  --namespace jupyterhub --create-namespace
```

The default authenticator is intended for local evaluation. Before exposing a
route, configure `auth.dummyPassword`, explicitly accept the insecure mode, or
provide a real authenticator through `hub.extraConfig`.

## Configuration

The three internal listeners and their Service-facing counterparts are
separate contracts. `containerPorts.*` controls the ports on which the Hub and
proxy processes actually listen. `service.*` controls stable Kubernetes
Service ports. Named `targetPort` values connect each Service to its matching
container listener.

| Purpose | Process listener | Service port | Default |
|---|---|---|---|
| Hub API and UI | `containerPorts.hub` | `service.hubPort` | `8081` |
| Public proxy | `containerPorts.proxy` | `service.port` | `8000` / `80` |
| Proxy control API | `containerPorts.proxyApi` | `service.proxyApiPort` | `8001` |

The proxy public listener and proxy API listener must use different container
ports. The chart validates this because configurable-http-proxy cannot bind two
listeners to the same address and port. Service ports may differ from listener
ports; changing a Service port alone does not reconfigure the process.

For GitOps-managed credentials, set `proxy.existingSecret` and optionally
render an ExternalSecret. The referenced Secret key must contain the shared
configurable-http-proxy token consumed by both the Hub and proxy.

## Examples

Change the actual listeners while keeping conventional Service ports:

```yaml
containerPorts:
  hub: 18081
  proxy: 18000
  proxyApi: 18001

service:
  port: 80
  hubPort: 8081
  proxyApiPort: 8001
```

Select a pinned single-user image and provide controlled profiles:

```yaml
singleuser:
  image:
    name: quay.io/jupyter/scipy-notebook
    tag: "2026-05-26"
  profiles:
    - display_name: Standard
      slug: standard
      default: true
      kubespawner_override:
        cpu_limit: 1
        mem_limit: 2G
```

Expose the chart with Ingress only after configuring authentication:

```yaml
auth:
  type: custom

hub:
  extraConfig: |
    c.JupyterHub.authenticator_class = "nativeauthenticator.NativeAuthenticator"

ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: hub.example.com
      paths:
        - path: /
          pathType: Prefix
```

## Architecture

External traffic reaches the public proxy Service through a cluster Service,
Ingress, or Gateway API route. Configurable-http-proxy forwards Hub paths to
the Hub Service and user paths to notebook pods registered through its private
API. The Hub authenticates users, persists its state, and asks KubeSpawner to
create notebook pods through namespaced Kubernetes RBAC.

The chart sets `hub.cleanupServers=false`. Because the proxy is a separate
workload, normal Hub rollouts or node drains do not automatically terminate
running user servers. The Hub still needs durable state and a shared cookie
secret for resilient or multi-replica operation.

The default SQLite database is suitable for a single Hub replica. For multiple
replicas, configure an external database with `c.JupyterHub.db_url` in
`hub.extraConfig`. Disable Hub persistence or use storage that supports the
required multi-writer access mode. When persistence is disabled for an HA Hub,
set `hub.cookieSecret.existingSecret` so every replica can decrypt the same
login cookies.

## Security

Hub and proxy containers run as UID/GID 1000, disallow privilege escalation,
drop all Linux capabilities, use runtime-default seccomp, and mount a writable
temporary directory while keeping the root filesystem read-only. KubeSpawner
disables automounted service-account tokens for notebook pods by default.

Never expose the default passwordless DummyAuthenticator to an untrusted
network. The chart blocks public Ingress, Gateway, LoadBalancer, and NodePort
exposure unless dummy authentication has a password, an explicit insecure
acknowledgement is set, or a custom authenticator is configured. Treat
`hub.extraConfig` as executable Python configuration and review it accordingly.

Prometheus metrics stay authenticated by default. A ServiceMonitor currently
requires `metrics.authenticatePrometheus=false`; keep its Service private. If
the same release is publicly exposed, the additional
`metrics.allowPublicUnauthenticatedPrometheus=true` acknowledgement is required.

NetworkPolicy is optional because enforcement depends on the cluster CNI.
After enabling it, validate DNS, Kubernetes API access, image pulls, identity
provider callbacks, external database access, and notebook traffic. Add only
the minimum required database or private endpoint rules through
`networkPolicy.hub.egress` or `networkPolicy.extraEgress`.

## Troubleshooting

If the Hub stays unready, inspect the rendered ConfigMap and verify that
`hub_bind_url`, `hub_connect_url`, and the Hub Service ports match the intended
listener mapping. For proxy failures, compare the `--port` and `--api-port`
arguments with `containerPorts.proxy` and `containerPorts.proxyApi`, then check
that the proxy API Service uses the named `proxy-api` target port.

If user pods stay pending, describe the pod and inspect namespace events for
quota, RBAC, storage class, scheduling, or image-pull failures. If sessions
fail intermittently behind multiple Hub replicas, confirm that an external
database is configured and that all replicas use the same cookie Secret. If a
ServiceMonitor cannot scrape, verify the metrics authentication decision and
the Prometheus Operator selector labels.

Useful commands:

```bash
helm test jupyterhub -n jupyterhub
kubectl get pods,svc -n jupyterhub
kubectl logs -n jupyterhub deploy/jupyterhub-hub --since=10m
kubectl logs -n jupyterhub deploy/jupyterhub-proxy --since=10m
kubectl get events -n jupyterhub --sort-by=.lastTimestamp
```

## Documentation

- [Design](./DESIGN.md)
- [Production guide](./docs/production.md)
- [Networking](./docs/networking.md)
- [External Secrets](./docs/external-secrets.md)
- [Production values example](./examples/production.yaml)
- [Gateway API example](./examples/gateway.yaml)
- [External Secrets example](./examples/external-secrets.yaml)

## Security Scan: `jupyterhub`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **81.666664%** |

The score is a point-in-time configuration assessment, not a substitute for
cluster policy, vulnerability management, authentication review, backups, and
an end-to-end user workflow test in the target environment.
