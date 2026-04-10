# Envoy Gateway

A Helm chart for deploying [Envoy Gateway](https://gateway.envoyproxy.io/) v1.7.1 on Kubernetes. Envoy Gateway is a **Kubernetes operator** — it manages Envoy proxy pods automatically in response to Gateway API resources.

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
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

# Install with development profile (creates Gateway, example HTTPRoute, and backend)
helm install envoy-gateway oci://ghcr.io/helmforgedev/helm/envoy-gateway \
  --set profile=dev \
  --set gateway.create=true \
  --set gatewayAPI.examples.enabled=true

# Wait for EG to provision the proxy pods
kubectl wait --for=condition=programmed gateway/envoy-gateway-example --timeout=120s

# Get the proxy service IP (dynamically created by EG operator)
export GATEWAY_IP=$(kubectl get svc -l gateway.envoyproxy.io/owning-gateway-name=envoy-gateway-example \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
curl -H "Host: example.local" http://$GATEWAY_IP/
```

## How It Works

1. **Chart installs**: GatewayClass, EnvoyProxy CRD, certgen job, controller Deployment, RBAC
2. **certgen job** runs as a pre-install hook and generates TLS certs for the controller
3. **Controller** starts and watches for `Gateway` resources
4. When `gateway.create: true`, a **Gateway** resource is created → EG automatically provisions Envoy proxy pods and a Service
5. Users create **HTTPRoute**, **TCPRoute**, **GRPCRoute** resources that attach to the Gateway
6. Policies (SecurityPolicy, BackendTrafficPolicy, ClientTrafficPolicy) attach to Gateway or HTTPRoute resources

Proxy pods are named `envoy-<namespace>-<gateway-name>-<uid>` and are managed entirely by the EG operator — not by this chart.

## Features

- **Profile Presets** — Production-ready configurations (dev, production-ha, custom)
- **Gateway API Native** — First-class support for Gateway API v1 resources
- **Operator Architecture** — EG provisions proxy pods automatically via the `Gateway` resource
- **SecurityPolicy** — Native JWT, OIDC, API Key, and CORS authentication
- **BackendTrafficPolicy** — Retries, timeouts, and circuit breaking
- **ClientTrafficPolicy** — Connection limits and TLS listener settings
- **Certgen Job** — Automatic TLS cert generation for controller webhook and xDS server
- **Rate Limiting** — Distributed rate limiting with Redis backend and presets
- **Comprehensive Observability** — Prometheus ServiceMonitor, alerts, and Grafana dashboards
- **Security Hardening** — NetworkPolicies, PodSecurityStandards, RBAC
- **High Availability** — DaemonSet proxy mode, leader election, anti-affinity, PodDisruptionBudgets
- **Gateway API Examples** — Working Gateway, HTTPRoute, and backend for quick validation

## Configuration

### Minimal (Development)

```yaml
profile: dev

gateway:
  create: true

gatewayAPI:
  examples:
    enabled: true
```

### Production (High Availability)

```yaml
profile: production-ha

proxy:
  kind: DaemonSet  # One proxy per node
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"

gateway:
  create: true
  listeners:
    http:
      enabled: true
      port: 80
    https:
      enabled: true
      port: 443
      tls:
        mode: Terminate
        certificateRef:
          name: my-tls-cert  # Created separately

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
| `profile` | `custom` | Profile preset (dev, production-ha, custom) |
| `nameOverride` | `""` | Override chart name |
| `fullnameOverride` | `""` | Override full name |
| `imagePullSecrets` | `[]` | Image pull secrets |

### Controller

| Key | Default | Description |
|-----|---------|-------------|
| `controller.replicaCount` | `1` | Number of controller replicas (overridden by profile) |
| `controller.image.repository` | `docker.io/envoyproxy/gateway` | Controller image repository |
| `controller.image.tag` | `v1.7.1` | Controller image tag |
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

### Certgen

| Key | Default | Description |
|-----|---------|-------------|
| `certgen.enabled` | `true` | Run certgen pre-install/pre-upgrade job for controller TLS certs |
| `certgen.image.repository` | `docker.io/envoyproxy/gateway` | Certgen image (same as controller) |
| `certgen.image.tag` | `v1.7.1` | Certgen image tag |
| `certgen.resources.requests.cpu` | `10m` | CPU request |
| `certgen.resources.requests.memory` | `64Mi` | Memory request |
| `certgen.resources.limits.cpu` | `100m` | CPU limit |
| `certgen.resources.limits.memory` | `128Mi` | Memory limit |

### Proxy (EnvoyProxy CRD)

`proxy.*` values configure the `EnvoyProxy` CRD, which tells the EG operator how to provision Envoy proxy pods. The proxy pods themselves are managed by EG, not by this chart.

| Key | Default | Description |
|-----|---------|-------------|
| `proxy.kind` | `Deployment` | Proxy workload kind: `Deployment` or `DaemonSet` |
| `proxy.replicaCount` | `1` | Number of proxy replicas (Deployment mode only, overridden by profile) |
| `proxy.image.repository` | `docker.io/envoyproxy/envoy` | Proxy image repository |
| `proxy.image.tag` | `distroless-v1.33.0` | Proxy image tag |
| `proxy.image.pullPolicy` | `IfNotPresent` | Image pull policy |
| `proxy.resources.requests.cpu` | `100m` | CPU request (overridden by profile) |
| `proxy.resources.requests.memory` | `128Mi` | Memory request (overridden by profile) |
| `proxy.resources.limits.cpu` | `1000m` | CPU limit (overridden by profile) |
| `proxy.resources.limits.memory` | `1Gi` | Memory limit (overridden by profile) |
| `proxy.service.type` | `LoadBalancer` | Service type for EG-provisioned proxy service |
| `proxy.service.httpPort` | `80` | HTTP port |
| `proxy.service.httpsPort` | `443` | HTTPS port |
| `proxy.service.annotations` | `{}` | Service annotations |
| `proxy.hpa.enabled` | `false` | Enable HPA for proxy (Deployment kind only) |
| `proxy.hpa.minReplicas` | `2` | Minimum replicas for HPA |
| `proxy.hpa.maxReplicas` | `10` | Maximum replicas for HPA |
| `proxy.hpa.targetCPUUtilizationPercentage` | `80` | Target CPU utilization |
| `proxy.nodeSelector` | `{}` | Node selector for proxy pods |
| `proxy.tolerations` | `[]` | Tolerations for proxy pods |

### Gateway

| Key | Default | Description |
|-----|---------|-------------|
| `gateway.create` | `false` | Create a default Gateway resource (triggers proxy provisioning) |
| `gateway.name` | `""` | Gateway name (defaults to release name) |
| `gateway.listeners.http.enabled` | `true` | Enable HTTP listener |
| `gateway.listeners.http.port` | `80` | HTTP listener port |
| `gateway.listeners.https.enabled` | `false` | Enable HTTPS listener |
| `gateway.listeners.https.port` | `443` | HTTPS listener port |
| `gateway.listeners.https.tls.mode` | `Terminate` | TLS mode (Terminate or Passthrough) |
| `gateway.listeners.https.tls.certificateRef.name` | `""` | TLS Secret name (must be created separately) |

### SecurityPolicy

| Key | Default | Description |
|-----|---------|-------------|
| `securityPolicy.create` | `false` | Create a SecurityPolicy resource |
| `securityPolicy.jwt.enabled` | `false` | Enable JWT authentication |
| `securityPolicy.jwt.providers` | `[]` | JWT provider configurations |
| `securityPolicy.oidc.enabled` | `false` | Enable OIDC/OAuth2 authentication |
| `securityPolicy.oidc.provider.issuer` | `""` | OIDC issuer URL |
| `securityPolicy.oidc.clientID` | `""` | OIDC client ID |
| `securityPolicy.oidc.clientSecret` | See values | Secret reference for OIDC client secret |
| `securityPolicy.apiKey.enabled` | `false` | Enable API Key authentication |
| `securityPolicy.cors.enabled` | `false` | Enable CORS policy |
| `securityPolicy.cors.allowOrigins` | `[]` | Allowed CORS origins |

### BackendTrafficPolicy

| Key | Default | Description |
|-----|---------|-------------|
| `backendTrafficPolicy.create` | `false` | Create a BackendTrafficPolicy resource |
| `backendTrafficPolicy.retry.enabled` | `false` | Enable retry policy |
| `backendTrafficPolicy.retry.numRetries` | `3` | Number of retries |
| `backendTrafficPolicy.circuitBreaker.enabled` | `false` | Enable circuit breaker |
| `backendTrafficPolicy.timeout.request` | `""` | Request timeout (e.g., `30s`) |

### ClientTrafficPolicy

| Key | Default | Description |
|-----|---------|-------------|
| `clientTrafficPolicy.create` | `false` | Create a ClientTrafficPolicy resource |
| `clientTrafficPolicy.connectionLimit.value` | `0` | Max concurrent connections (0 = unlimited) |
| `clientTrafficPolicy.http2.enabled` | `false` | Enable HTTP/2 on listeners |

### Gateway API Examples

| Key | Default | Description |
|-----|---------|-------------|
| `gatewayAPI.examples.enabled` | `true` | Create example Gateway, HTTPRoute, and backend |
| `gatewayAPI.examples.namespace` | `""` | Namespace for examples (defaults to Release.Namespace) |

### Rate Limiting

| Key | Default | Description |
|-----|---------|-------------|
| `rateLimiting.enabled` | `false` | Enable rate limiting |
| `rateLimiting.redis.enabled` | `false` | Deploy Redis StatefulSet |
| `rateLimiting.redis.image.repository` | `docker.io/redis` | Redis image repository |
| `rateLimiting.redis.image.tag` | `8.0.2-alpine` | Redis image tag |
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
| `monitoring.prometheus.serviceMonitor` | `true` | Create Prometheus ServiceMonitor (controller only) |
| `monitoring.prometheus.prometheusRule` | `false` | Create PrometheusRule with 6 alert rules |
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
- [Production](examples/production.yaml) — full HA with DaemonSet proxy, rate limiting, monitoring, and security
- [Staging](examples/staging.yaml) — 2 replicas with monitoring
- [Rate Limiting](examples/rate-limiting.yaml) — API gateway with Redis rate limiting

## Architecture Guides

- [Architecture](docs/architecture.md) — EG operator model and component overview
- [Security Policies](docs/security-policies.md) — JWT, OIDC, API Key, CORS configuration
- [Rate Limiting](docs/rate-limiting.md) — distributed rate limiting with Redis backend
- [Certificates](docs/certificates.md) — certgen job and HTTPS listener TLS configuration
- [Observability](docs/observability.md) — Prometheus metrics, alerts, and Grafana dashboards

## Connection

After installation, connect to the Gateway:

```bash
# List EG-managed proxy services (dynamically named by EG operator)
kubectl get svc -l gateway.envoyproxy.io/owning-gateway-name=<gateway-name>

# Get Gateway IP
export GATEWAY_IP=$(kubectl get svc -l gateway.envoyproxy.io/owning-gateway-name=<gateway-name> \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')

# Test example HTTPRoute
curl -H "Host: example.local" http://$GATEWAY_IP/

# View controller logs
kubectl logs -l app.kubernetes.io/component=controller -f

# View proxy logs (pods are dynamically named)
kubectl get pods -l app.kubernetes.io/component=proxy
kubectl logs <envoy-pod-name> -f

# Check Gateway status
kubectl describe gateway <gateway-name>

# Access Envoy admin interface
kubectl port-forward <proxy-pod> 19000:19000
# Visit http://localhost:19000/
```

## Profile Presets

The chart includes profile presets for quick deployment:

| Profile | Controller | Proxy | Resources | Use Case |
|---------|-----------|-------|-----------|----------|
| **dev** | 1 replica | 1 replica (Deployment) | Minimal (100m/128Mi) | Local development |
| **production-ha** | 2 replicas | DaemonSet | Production (1000m/1Gi) | Production |
| **custom** | Configurable | Configurable | Configurable | Full control |

Switch profiles with:

```bash
helm upgrade envoy-gateway helmforge/envoy-gateway --set profile=production-ha --reuse-values
```

## Migration Guide

### Version 1.3.0 (EG v1.7.1)

Major architectural redesign to align with the EG operator model.

**Breaking Changes**:
- `proxy.mode` renamed to `proxy.kind`
- `certificates.certManager` section removed — use external cert-manager and reference Secrets in Gateway listeners
- `profile: staging` removed — use `profile: custom` with explicit values
- Proxy Deployment/DaemonSet/Service/HPA are no longer managed by this chart (EG operator manages them via EnvoyProxy CRD)

**New Features**:
- `certgen` job for automatic controller TLS cert generation
- `gateway.create` for optional default Gateway provisioning
- `SecurityPolicy` CRD: JWT, OIDC, API Key, CORS
- `BackendTrafficPolicy` CRD: retries, circuit breaking, timeouts
- `ClientTrafficPolicy` CRD: connection limits, HTTP/2 settings
- Updated to EG v1.7.1 and Redis 8.0.2-alpine

### Version 1.0.0

First stable release with MVP and production features.

## Non-Goals

This chart intentionally does not support:

- **Multiple gateway classes** — Deploy separate releases for multiple GatewayClasses
- **Built-in cert-manager integration** — Manage application TLS externally; chart only runs certgen for controller certs
- **Legacy Ingress API** — Use Gateway API for modern routing capabilities

<!-- @AI-METADATA
type: chart-readme
title: Envoy Gateway Helm Chart
description: Deploy Envoy Gateway v1.7.1 on Kubernetes with operator architecture, SecurityPolicy, rate limiting, and comprehensive observability
keywords: envoy, gateway, gateway-api, helm, kubernetes, rate-limiting, prometheus, grafana, redis, networking, securitypolicy, backendtrafficpolicy, clienttrafficpolicy
purpose: Installation guide, configuration reference, and operational documentation for the Envoy Gateway Helm chart
scope: Chart
relations:
  - charts/envoy-gateway/docs/architecture.md
  - charts/envoy-gateway/docs/rate-limiting.md
  - charts/envoy-gateway/docs/certificates.md
  - charts/envoy-gateway/docs/observability.md
  - charts/envoy-gateway/docs/security-policies.md
  - charts/envoy-gateway/values.yaml
path: charts/envoy-gateway/README.md
version: 1.3.0
date: 2026-04-10
-->
