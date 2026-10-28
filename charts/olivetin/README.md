# OliveTin Helm Chart

Deploy [OliveTin](https://www.olivetin.app) on Kubernetes using the official
[jamesread/olivetin](https://hub.docker.com/r/jamesread/olivetin) container image.
OliveTin gives safe and simple access to predefined shell commands from a web interface.

## Features

- **Web UI for shell commands** — define actions in YAML, run them from the browser
- **Zero dependencies** — stateless, no database required
- **Configuration via ConfigMap** — YAML config mounted at /config/config.yaml
- **Prometheus metrics** — optional /metrics endpoint with ServiceMonitor support
- **Ingress support** — TLS with cert-manager
- **Gateway API support** — optional HTTPRoute rendering for modern ingress controllers
- **External Secrets support** — optional ExternalSecret resources for command credentials
- **Dual-stack Service support** — optional `ipFamilyPolicy` and `ipFamilies`
- **Authoritative application port** — `olivetin.port` configures both Kubernetes and OliveTin through `PORT`
- **Optional persistence** — dynamically provision a data PVC or attach an existing claim
- **Lightweight** — minimal resource usage

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install olivetin helmforge/olivetin -f values.yaml
```

**OCI registry:**

```bash
helm install olivetin oci://ghcr.io/helmforgedev/helm/olivetin -f values.yaml
```

## Basic Example

```yaml
# values.yaml
config: |
  actions:
    - title: "Ping Google"
      shell: "ping -c 1 google.com"
    - title: "Check Disk Usage"
      shell: "df -h"
```

After deploying:

```bash
kubectl port-forward svc/<release>-olivetin 1337:80
# Open http://localhost:1337
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `configInit.enabled` | `true` | Prepare writable OliveTin runtime files before startup |
| `configInit.resources` | requests/limits set | Resource guardrails for the config bootstrap init container |
| `configInit.securityContext` | non-root | Security context for the config bootstrap init container |
| `image.tag` | `3000.20.0` | OliveTin image tag |
| `securityContext` | non-root | Security context for the OliveTin application container |
| `olivetin.port` | `1337` | Application port, propagated through OliveTin's `PORT` environment variable |
| `config` | `""` | OliveTin YAML configuration. Empty uses the chart-managed default config. |
| `configTpl.enabled` | `false` | Opt in to Helm `tpl` rendering for `config` |
| `persistence.enabled` | `false` | Enable optional PVC for data |
| `persistence.size` | `1Gi` | PVC size |
| `ingress.enabled` | `false` | Enable ingress |
| `service.port` | `80` | Service port |
| `service.ipFamilyPolicy` | omitted | Optional Service IP family policy for dual-stack clusters |
| `gatewayAPI.enabled` | `false` | Enable Gateway API HTTPRoute rendering |
| `gatewayAPI.httpRoutes[].rules[].omitDefaultBackend` | `false` | Omit the default Service backend for redirect-only rules |
| `externalSecrets.enabled` | `false` | Render ExternalSecret resources for command credentials |
| `externalSecrets.apiVersion` | `external-secrets.io/v1` | ExternalSecret API version |
| `externalSecrets.refreshInterval` | `1h` | Default provider sync interval |
| `externalSecrets.items` | `[]` | ExternalSecret item list with full ESO `spec` blocks |
| `metrics.enabled` | `false` | Enable Prometheus metrics |
| `metrics.port` | `1341` | Dedicated Prometheus listener and Service port |
| `metrics.defaultGoMetrics` | `false` | Expose default Go runtime metrics |
| `metrics.serviceMonitor.enabled` | `false` | Create ServiceMonitor |
| `resources` | requests/limits set | Default CPU and memory requests and limits |
| `serviceAccount.automountServiceAccountToken` | `false` | Prevent automatic API token mounting |

## Prometheus Metrics

OliveTin exposes metrics at `/metrics`. To enable scraping with Prometheus Operator:

```yaml
metrics:
  enabled: true
  port: 1341
  defaultGoMetrics: false
  serviceMonitor:
    enabled: true
    interval: 30s
```

OliveTin serves Prometheus metrics on a separate internal listener. The chart
binds that listener to `0.0.0.0:<metrics.port>`, exposes the named `metrics`
Service port, and configures ServiceMonitor to scrape `/metrics`. Enabling a
ServiceMonitor without metrics is rejected.

## Configuration

The `config` value is mounted as `/config/config.yaml` inside the container. It is not rendered through Helm `tpl` by default,
so OliveTin runtime expressions such as `{{ message }}` remain literal for OliveTin to evaluate. Set `configTpl.enabled=true`
only when you intentionally want Helm to render templates inside `config`.

The chart parses the result as YAML and owns the `prometheus` and
`listenAddressPrometheus` settings so metrics work consistently with starter
and custom configurations. When metrics are disabled, it forces
`prometheus.enabled=false` and removes any custom Prometheus listener address.
See the
[chart configuration guide](docs/configuration.md) and the
[OliveTin documentation](https://docs.olivetin.app) for all available options.

## Upgrade Notes

OliveTin `3000.18.0` added `dnsname` action arguments and configuration issues
in diagnostics. OliveTin `3000.20.0` adds dashboard categories, persistent log
filters, and support for the `PORT` environment variable. It also fixes
`shellAfterCompleted` output injection, HTTP timeout and path traversal
weaknesses, and unsafe theme permissions. Upstream reports no breaking changes.
The chart now propagates `olivetin.port` through `PORT`; remove any duplicate
`PORT` entry from `olivetin.extraEnv` and configure the port only through
`olivetin.port`. Enabling persistence now creates the data PVC when
`persistence.existingClaim` is empty.

## Security

OliveTin executes operator-defined shell commands. Do not expose it publicly
without configuring OliveTin authentication and ACLs or an authenticated
reverse proxy. Trusted-header authentication also requires preventing clients
from bypassing that proxy.

The chart defaults to a non-root container, drops all capabilities, disables
privilege escalation, uses runtime-default seccomp, and does not mount a
ServiceAccount token. If actions call the Kubernetes API, explicitly enable the
token and bind only the minimum RBAC. Keep credentials in Kubernetes Secrets or
External Secrets; `values.config` is stored in a ConfigMap.

The optional `/data` PVC stores only files that actions deliberately write
there. Session files, themes, and logs under `/config` remain ephemeral. The
chart does not create NetworkPolicy because action destinations are specific to
each deployment.

### Security Scan: olivetin

| Framework          | Score   |
| ------------------ | ------- |
| MITRE + NSA + SOC2 | **95%** |

Security posture: acceptable.

## Ingress Example

```yaml
ingress:
  enabled: true
  ingressClassName: traefik  # or nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
  hosts:
    - host: olivetin.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - olivetin.example.com
      secretName: olivetin-tls
```

## Gateway API Example

```yaml
gatewayAPI:
  enabled: true
  httpRoutes:
    - name: web
      parentRefs:
        - name: public
          namespace: gateway-system
      hostnames:
        - olivetin.example.com
```

## External Secrets Example

```yaml
externalSecrets:
  enabled: true
  items:
    - name: command-credentials
      spec:
        secretStoreRef:
          name: platform-secrets
          kind: ClusterSecretStore
        target:
          name: olivetin-command-credentials
          creationPolicy: Owner
        data:
          - secretKey: API_TOKEN
            remoteRef:
              key: olivetin/api-token

olivetin:
  extraEnv:
    - name: API_TOKEN
      valueFrom:
        secretKeyRef:
          name: olivetin-command-credentials
          key: API_TOKEN
```

## More Information

- [OliveTin documentation](https://docs.olivetin.app)
- [OliveTin source](https://github.com/OliveTin/OliveTin)
- [HelmForge chart source](https://github.com/helmforgedev/charts/tree/main/charts/olivetin)
