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
| `configInit.securityContext` | non-root | Security context for the config bootstrap init container |
| `image.tag` | `3000.14.0` | OliveTin image tag |
| `securityContext` | non-root | Security context for the OliveTin application container |
| `olivetin.port` | `1337` | Application port |
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
| `metrics.defaultGoMetrics` | `false` | Expose default Go runtime metrics |
| `metrics.serviceMonitor.enabled` | `false` | Create ServiceMonitor |

## Prometheus Metrics

OliveTin exposes metrics at `/metrics`. To enable scraping with Prometheus Operator:

```yaml
metrics:
  enabled: true
  defaultGoMetrics: false
  serviceMonitor:
    enabled: true
    interval: 30s
```

## Configuration

The `config` value is mounted as `/config/config.yaml` inside the container. It is not rendered through Helm `tpl` by default,
so OliveTin runtime expressions such as `{{ message }}` remain literal for OliveTin to evaluate. Set `configTpl.enabled=true`
only when you intentionally want Helm to render templates inside `config`.

See the [OliveTin documentation](https://docs.olivetin.app) for all available options.

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
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/olivetin)

<!-- @AI-METADATA
type: chart-readme
title: OliveTin Helm Chart
description: README for the OliveTin web interface for shell commands Helm chart

keywords: olivetin, shell, commands, automation, web-ui, self-hosted

purpose: Chart installation, configuration, and usage documentation
scope: Chart

relations:
  - charts/olivetin/values.yaml
  - charts/olivetin/DESIGN.md
  - charts/olivetin/docs/configuration.md
path: charts/olivetin/README.md
version: 1.1
date: 2026-06-02
-->
