# Envoy Gateway

A Helm chart for deploying [Envoy Gateway](https://gateway.envoyproxy.io/) on Kubernetes using the official [envoyproxy/gateway](https://hub.docker.com/r/envoyproxy/gateway) controller and [envoyproxy/envoy](https://hub.docker.com/r/envoyproxy/envoy) proxy images.

## Installation

### HTTPS Repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install envoy-gateway helmforge/envoy-gateway
```

### OCI Registry

```bash
helm install envoy-gateway oci://ghcr.io/helmforgedev/helm/envoy-gateway
```

## Quick Start

```bash
# Install Gateway API CRDs
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml

# Install with development profile
helm install envoy-gateway oci://ghcr.io/helmforgedev/helm/envoy-gateway \
  --set profile=dev

# Test the example Gateway
export GATEWAY_IP=$(kubectl get svc envoy-gateway-proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -H "Host: example.local" http://$GATEWAY_IP/
```

## Features

- **Profile Presets** — Production-ready configurations (dev, staging, production-ha)
- **Gateway API Native** — First-class support for Gateway API v1 resources
- **Certificate Management** — Automated TLS with cert-manager integration
- **Rate Limiting** — Distributed rate limiting with Redis backend and presets
- **Comprehensive Observability** — Prometheus ServiceMonitors, alerts, and Grafana dashboards
- **Security Hardening** — NetworkPolicies, PodSecurityStandards, RBAC
- **High Availability** — DaemonSet proxy mode, leader election, anti-affinity, PodDisruptionBudgets
- **Gateway API Examples** — Working Gateway, HTTPRoute, and backend for quick validation

## Configuration

### Minimal (Development)

```yaml
profile: dev

gatewayAPI:
  examples:
    enabled: true
```

### Production (High Availability)

```yaml
profile: production-ha

gatewayClass:
  name: envoy-gateway

certificates:
  certManager:
    enabled: true
    issuer: letsencrypt-prod
    issuerKind: ClusterIssuer

rateLimiting:
  enabled: true
  redis:
    enabled: true
    persistence:
      enabled: true
      size: 2Gi
  presets:
    api: true

monitoring:
  enabled: true
  prometheus:
    serviceMonitor: true
    prometheusRule: true
  grafana:
    dashboards: true
  accessLogs:
    enabled: true
    format: json

security:
  networkPolicies: true
  podSecurityStandards: true

highAvailability:
  enabled: true
  podDisruptionBudget:
    minAvailable: 1
```

## Parameters

### Global

| Key | Default | Description |
|-----|---------|-------------|
| `profile` | `custom` | Profile preset (dev, staging, production-ha, custom) |
| `nameOverride` | `""` | Override chart name |
| `fullnameOverride` | `""` | Override full name |
| `imagePullSecrets` | `[]` | Image pull secrets |

### Controller

| Key | Default | Description |
|-----|---------|-------------|
| `controller.replicaCount` | `1` | Number of controller replicas (overridden by profile) |
| `controller.image.repository` | `docker.io/envoyproxy/gateway` | Controller image repository |
| `controller.image.tag` | `v1.0.0` | Controller image tag |
| `controller.image.pullPolicy` | `IfNotPresent` | Image pull policy |
| `controller.resources.requests.cpu` | `100m` | CPU request (overridden by profile) |
| `controller.resources.requests.memory` | `128Mi` | Memory request (overridden by profile) |
| `controller.resources.limits.cpu` | `500m` | CPU limit (overridden by profile) |
| `controller.resources.limits.memory` | `512Mi` | Memory limit (overridden by profile) |
| `controller.nodeSelector` | `{}` | Node selector |
| `controller.tolerations` | `[]` | Tolerations |
| `controller.affinity` | `{}` | Affinity rules (anti-affinity set by production-ha) |
| `controller.podSecurityContext` | See values | Pod security context |
| `controller.securityContext` | See values | Container security context |

### Proxy

| Key | Default | Description |
|-----|---------|-------------|
| `proxy.mode` | `Deployment` | Proxy mode: Deployment or DaemonSet (overridden by profile) |
| `proxy.replicaCount` | `1` | Number of proxy replicas (Deployment mode only, overridden by profile) |
| `proxy.image.repository` | `docker.io/envoyproxy/envoy` | Proxy image repository |
| `proxy.image.tag` | `v1.29.0` | Proxy image tag |
| `proxy.image.pullPolicy` | `IfNotPresent` | Image pull policy |
| `proxy.resources.requests.cpu` | `100m` | CPU request (overridden by profile) |
| `proxy.resources.requests.memory` | `128Mi` | Memory request (overridden by profile) |
| `proxy.resources.limits.cpu` | `1000m` | CPU limit (overridden by profile) |
| `proxy.resources.limits.memory` | `1Gi` | Memory limit (overridden by profile) |
| `proxy.service.type` | `LoadBalancer` | Service type for proxy |
| `proxy.service.httpPort` | `80` | HTTP port |
| `proxy.service.httpsPort` | `443` | HTTPS port |
| `proxy.service.annotations` | `{}` | Service annotations |
| `proxy.autoscaling.enabled` | `false` | Enable HorizontalPodAutoscaler (Deployment mode only) |
| `proxy.autoscaling.minReplicas` | `2` | Minimum replicas for HPA |
| `proxy.autoscaling.maxReplicas` | `10` | Maximum replicas for HPA |
| `proxy.autoscaling.targetCPUUtilizationPercentage` | `80` | Target CPU utilization |
| `proxy.nodeSelector` | `{}` | Node selector |
| `proxy.tolerations` | `[]` | Tolerations |
| `proxy.affinity` | `{}` | Affinity rules (anti-affinity set by production-ha) |
| `proxy.podSecurityContext` | See values | Pod security context |
| `proxy.securityContext` | See values | Container security context |

### Gateway API Examples

| Key | Default | Description |
|-----|---------|-------------|
| `gatewayAPI.examples.enabled` | `true` | Create example Gateway, HTTPRoute, and backend |
| `gatewayAPI.examples.namespace` | `""` | Namespace for examples (defaults to Release.Namespace) |

### Certificate Management

| Key | Default | Description |
|-----|---------|-------------|
| `certificates.certManager.enabled` | `false` | Enable cert-manager integration (enabled by staging/production-ha profiles) |
| `certificates.certManager.issuer` | `selfsigned` | Issuer or ClusterIssuer name |
| `certificates.certManager.issuerKind` | `ClusterIssuer` | Issuer kind (ClusterIssuer or Issuer) |
| `certificates.autoProvision` | `false` | Auto-provision certificates for Gateway listeners |

### Rate Limiting

| Key | Default | Description |
|-----|---------|-------------|
| `rateLimiting.enabled` | `false` | Enable rate limiting |
| `rateLimiting.redis.enabled` | `false` | Deploy Redis StatefulSet |
| `rateLimiting.redis.image.repository` | `docker.io/redis` | Redis image repository |
| `rateLimiting.redis.image.tag` | `7.2-alpine` | Redis image tag |
| `rateLimiting.redis.resources` | See values | Redis resources |
| `rateLimiting.redis.persistence.enabled` | `true` | Enable Redis persistence |
| `rateLimiting.redis.persistence.size` | `1Gi` | Redis PVC size |
| `rateLimiting.redis.persistence.storageClass` | `""` | Storage class for Redis PVC |
| `rateLimiting.externalRedis.host` | `""` | External Redis host |
| `rateLimiting.externalRedis.port` | `6379` | External Redis port |
| `rateLimiting.externalRedis.auth.enabled` | `false` | Enable Redis authentication |
| `rateLimiting.externalRedis.auth.secretName` | `""` | Secret name for Redis password |
| `rateLimiting.externalRedis.auth.secretKey` | `password` | Secret key for Redis password |
| `rateLimiting.presets.api` | `false` | Enable API preset (100 req/min per IP) |
| `rateLimiting.presets.strict` | `false` | Enable strict preset (10 req/min per IP) |

### Monitoring

| Key | Default | Description |
|-----|---------|-------------|
| `monitoring.enabled` | `false` | Enable monitoring |
| `monitoring.prometheus.serviceMonitor` | `true` | Create Prometheus ServiceMonitors |
| `monitoring.prometheus.prometheusRule` | `false` | Create PrometheusRule with alert rules |
| `monitoring.grafana.dashboards` | `false` | Create Grafana dashboard ConfigMap |
| `monitoring.accessLogs.enabled` | `true` | Enable access logs |
| `monitoring.accessLogs.format` | `json` | Access log format (json or text) |

### Security

| Key | Default | Description |
|-----|---------|-------------|
| `security.networkPolicies` | `false` | Enable NetworkPolicies |
| `security.podSecurityStandards` | `true` | Enable PodSecurityStandards (restricted mode) |

### High Availability

| Key | Default | Description |
|-----|---------|-------------|
| `highAvailability.enabled` | `false` | Enable HA mode (enabled by production-ha profile) |
| `highAvailability.podDisruptionBudget.minAvailable` | `1` | Minimum available pods for PDB |

### RBAC and ServiceAccount

| Key | Default | Description |
|-----|---------|-------------|
| `serviceAccount.create` | `true` | Create ServiceAccount |
| `serviceAccount.name` | `""` | ServiceAccount name (generated if empty) |
| `serviceAccount.annotations` | `{}` | ServiceAccount annotations |
| `rbac.create` | `true` | Create RBAC resources |

### GatewayClass

| Key | Default | Description |
|-----|---------|-------------|
| `gatewayClass.name` | `envoy-gateway` | GatewayClass name |
| `gatewayClass.create` | `true` | Create GatewayClass resource |

## Examples

- [Simple](examples/simple.yaml) — minimal deployment with dev profile
- [Production](examples/production.yaml) — full HA with rate limiting, monitoring, and security
- [Staging](examples/staging.yaml) — 2 replicas with self-signed TLS
- [Rate Limiting](examples/rate-limiting.yaml) — API gateway with Redis rate limiting
- [Multi-Tenancy](examples/multi-tenancy.yaml) — namespace-based routing isolation

## Architecture Guides

- [Rate Limiting](docs/rate-limiting.md) — distributed rate limiting with Redis backend
- [Certificate Management](docs/certificates.md) — automated TLS with cert-manager
- [Observability](docs/observability.md) — Prometheus metrics, alerts, and Grafana dashboards

## Connection

After installation, connect to the Gateway:

```bash
# Get Gateway IP
kubectl get svc envoy-gateway-proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Test example HTTPRoute
export GATEWAY_IP=$(kubectl get svc envoy-gateway-proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -H "Host: example.local" http://$GATEWAY_IP/

# View controller logs
kubectl logs -l app.kubernetes.io/component=controller -f

# View proxy logs
kubectl logs -l app.kubernetes.io/component=proxy -f

# Check Gateway status
kubectl describe gateway envoy-gateway-example

# Access Envoy admin interface
kubectl port-forward <proxy-pod> 19000:19000
# Visit http://localhost:19000/
```

## Profile Presets

The chart includes three profile presets for quick deployment:

| Profile | Controller | Proxy | Resources | TLS | Use Case |
|---------|-----------|-------|-----------|-----|----------|
| **dev** | 1 replica | 1 replica (Deployment) | Minimal (100m/128Mi) | No | Local development |
| **staging** | 2 replicas | 2 replicas (Deployment) | Medium (500m/512Mi) | Self-signed | Pre-production |
| **production-ha** | 2 replicas | DaemonSet | Production (1000m/1Gi) | cert-manager | Production |
| **custom** | Configurable | Configurable | Configurable | Optional | Full control |

Switch profiles with:

```bash
helm upgrade envoy-gateway helmforge/envoy-gateway --set profile=production-ha --reuse-values
```

## Migration Guide

### Version 1.0.0

First stable release with P1 (MVP) and P2 (Production) features.

**Features**:
- Profile presets (dev, staging, production-ha)
- Gateway API examples
- cert-manager integration
- Rate limiting with Redis
- Observability (Prometheus, Grafana, alerts)
- Security hardening (NetworkPolicies, PodSecurityStandards)

All features are opt-in with no breaking changes.

## Non-Goals

This chart intentionally does not support:

- **Multiple gateway classes** — Deploy separate releases for multiple GatewayClasses
- **Custom Envoy images** — Use official Envoy Proxy images only
- **Legacy Ingress API** — Use Gateway API for modern routing capabilities
- **Built-in OAuth2 Proxy** — Use SecurityPolicy CRDs for authentication (P3 feature)

<!-- @AI-METADATA
type: chart-readme
title: Envoy Gateway Helm Chart
description: Deploy Envoy Gateway on Kubernetes with Gateway API examples, rate limiting, cert-manager, and comprehensive observability
keywords: envoy, gateway, gateway-api, helm, kubernetes, rate-limiting, cert-manager, prometheus, grafana, redis, networking
purpose: Installation guide, configuration reference, and operational documentation for the Envoy Gateway Helm chart
scope: Chart
relations:
  - charts/envoy-gateway/docs/rate-limiting.md
  - charts/envoy-gateway/docs/certificates.md
  - charts/envoy-gateway/docs/observability.md
  - charts/envoy-gateway/values.yaml
path: charts/envoy-gateway/README.md
version: 1.0
date: 2026-04-09
-->
