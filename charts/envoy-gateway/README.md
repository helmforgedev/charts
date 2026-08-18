# Envoy Gateway

A Helm chart for deploying [Envoy Gateway](https://gateway.envoyproxy.io/)
v1.9.0 on Kubernetes 1.33 through 1.36. Envoy Gateway is a **Kubernetes
operator** — it manages Envoy proxy pods automatically in response to Gateway
API resources.

> [!WARNING]
> **Upgrading from chart 1.x to 2.0.0 requires a staged CRD migration.**
>
> Do not upgrade directly with `crds.enabled=false`, uninstall the bundled CRDs,
> or replace the safe-upgrade policy. Use this order:
>
> 1. Upgrade Kubernetes first when it is outside the supported 1.33-1.36 range.
> 2. Capture all CRD, custom-resource, policy, and binding UIDs.
> 3. Upgrade Envoy Gateway to 2.0.0 with `crds.enabled=true` so Helm records the
>    keep policy.
> 4. Install `envoy-gateway-crds` 1.0.0 with policy management disabled and
>    server-side apply its locked bundle.
> 5. Upgrade Envoy Gateway 2.0.0 with `crds.enabled=false`.
> 6. Transfer the policy and binding to the standalone release, then verify all
>    captured UIDs and Gateway traffic.
>
> CRD schema upgrades are forward-only. Do not use Helm rollback to downgrade
> the bundle or return the application to a pre-2.0.0 revision. Follow the
> [complete 1.x to 2.0.0 migration procedure](docs/crd-migration.md) before
> changing production releases.

## Installation

### HTTPS Repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm upgrade --install envoy-gateway-crds helmforge/envoy-gateway-crds \
  --version 1.0.0 \
  --namespace envoy-gateway \
  --create-namespace
helm show crds helmforge/envoy-gateway-crds \
  --version 1.0.0 > envoy-gateway-crds-installed.yaml
kubectl wait --for=condition=Established --timeout=120s \
  -f envoy-gateway-crds-installed.yaml
kubectl api-resources --api-group=gateway.networking.k8s.io
kubectl api-resources --api-group=gateway.envoyproxy.io
helm upgrade --install envoy-gateway helmforge/envoy-gateway \
  --namespace envoy-gateway \
  --set crds.enabled=false
```

### OCI Registry

```bash
helm upgrade --install envoy-gateway-crds \
  oci://ghcr.io/helmforgedev/helm/envoy-gateway-crds \
  --version 1.0.0 \
  --namespace envoy-gateway \
  --create-namespace
helm show crds oci://ghcr.io/helmforgedev/helm/envoy-gateway-crds \
  --version 1.0.0 > envoy-gateway-crds-installed.yaml
kubectl wait --for=condition=Established --timeout=120s \
  -f envoy-gateway-crds-installed.yaml
kubectl api-resources --api-group=gateway.networking.k8s.io
kubectl api-resources --api-group=gateway.envoyproxy.io
helm upgrade --install envoy-gateway \
  oci://ghcr.io/helmforgedev/helm/envoy-gateway \
  --namespace envoy-gateway \
  --set crds.enabled=false
```

## Quick Start

Envoy Gateway v1.9.0 requires Gateway API v1.6.1 Experimental and supports
Kubernetes 1.33 through 1.36. New installations use the standalone
`envoy-gateway-crds` release first, wait for discovery, then install this chart
with `crds.enabled=false`. This makes the first `helm diff` work with Kubernetes
validation enabled and gives CRDs an explicit forward-only lifecycle.

The bundled `crds` subchart remains enabled by default only as a migration
bridge for users upgrading from chart 1.10.1. Existing users must first upgrade
to this release with `crds.enabled=true`; that revision records
`helm.sh/resource-policy: keep` on the safe-upgrade policy and binding. They can
then install the standalone release, disable the old dependency, and transfer
policy ownership without deleting or recreating any CRD or custom resource.

Do not disable the bundled dependency directly from 1.10.1. Follow the
[mandatory migration procedure](docs/crd-migration.md).

```bash
# Install the controller after the standalone CRD release is Established.
helm upgrade --install envoy-gateway oci://ghcr.io/helmforgedev/helm/envoy-gateway \
  --namespace envoy-gateway \
  --set crds.enabled=false \
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

1. **CRD release installs**: 18 CRDs and the Gateway API safe-upgrade policy
2. **Application chart validates**: required discovery and bundle metadata
3. **certgen job** runs as a pre-install hook and generates TLS certs for the controller
4. **Controller** starts and watches for `Gateway` resources
5. When `gateway.create: true`, a **Gateway** resource is created and EG provisions Envoy proxy pods and a Service
6. Users create Routes and policies that attach to Gateway API resources

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
| `namespaceOverride` | `""` | Namespace for chart-managed resources; target namespace must already exist |
| `crds.enabled` | `true` | Migration bridge: retain bundled CRDs until the standalone release has been installed and ownership transferred |
| `nameOverride` | `""` | Override chart name |
| `fullnameOverride` | `""` | Override full name |
| `imagePullSecrets` | `[]` | Image pull secrets |
| `service.ipFamilyPolicy` | `null` | Dual-stack ipFamilyPolicy for controller Services |
| `service.ipFamilies` | `[]` | Dual-stack ipFamilies for controller Services |

### Controller

| Key | Default | Description |
|-----|---------|-------------|
| `controller.replicaCount` | `1` | Number of controller replicas (overridden by profile) |
| `controller.image.repository` | `docker.io/envoyproxy/gateway` | Controller image repository |
| `controller.image.tag` | `v1.9.0` | Controller image tag |
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
| `certgen.image.tag` | `v1.9.0` | Certgen image tag |
| `certgen.resources.requests.cpu` | `10m` | CPU request |
| `certgen.resources.requests.memory` | `64Mi` | Memory request |
| `certgen.resources.limits.cpu` | `100m` | CPU limit |
| `certgen.resources.limits.memory` | `128Mi` | Memory limit |

### Proxy (EnvoyProxy CRD)

`proxy.*` values configure the `EnvoyProxy` CRD, which tells the EG operator how to provision Envoy proxy pods. The proxy pods themselves are managed by EG, not by this chart.

| Key | Default | Description |
|-----|---------|-------------|
| `proxy.ipFamily` | `""` | EnvoyProxy IP family (`IPv4`, `IPv6`, or `DualStack`) |
| `proxy.kind` | `Deployment` | Proxy workload kind: `Deployment` or `DaemonSet` |
| `proxy.replicaCount` | `1` | Number of proxy replicas (Deployment mode only, overridden by profile) |
| `proxy.image.repository` | `docker.io/envoyproxy/envoy` | Proxy image repository |
| `proxy.image.tag` | `distroless-v1.39.0` | Proxy image tag |
| `proxy.image.pullPolicy` | `IfNotPresent` | Image pull policy |
| `proxy.shutdownManager.image.repository` | `docker.io/envoyproxy/gateway` | Shutdown manager sidecar image repository |
| `proxy.shutdownManager.image.tag` | `v1.9.0` | Shutdown manager sidecar image tag |
| `proxy.shutdownManager.image.pullPolicy` | `IfNotPresent` | Shutdown manager image pull policy |
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
| `gateway.create` | `true` | Create a default Gateway resource (triggers proxy provisioning) |
| `gateway.name` | `""` | Gateway name (defaults to release name) |
| `gateway.allowedListeners` | `{}` | ListenerSet namespace attachment policy; supports `None`, `Same`, `All`, and `Selector` |
| `gateway.listeners.http.enabled` | `true` | Enable HTTP listener |
| `gateway.listeners.http.port` | `80` | HTTP listener port |
| `gateway.listeners.http.allowedRoutes` | `{}` | Route kinds and namespaces allowed to attach; empty uses the same-namespace Gateway API default |
| `gateway.listeners.https.enabled` | `false` | Enable HTTPS listener |
| `gateway.listeners.https.port` | `443` | HTTPS listener port |
| `gateway.listeners.https.allowedRoutes` | `{}` | Route kinds and namespaces allowed to attach; empty uses the same-namespace Gateway API default |
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
| `gatewayAPI.enabled` | `true` | Enable chart-managed Gateway API helper resources |
| `gatewayAPI.examples.enabled` | `true` | Create example Gateway, HTTPRoute, and backend |
| `gatewayAPI.examples.namespace` | `""` | Namespace for examples (defaults to `namespaceOverride` or release namespace) |

### Rate Limiting

| Key | Default | Description |
|-----|---------|-------------|
| `rateLimiting.enabled` | `false` | Enable rate limiting |
| `rateLimiting.service.image.repository` | `docker.io/envoyproxy/ratelimit` | Rate limit service image repository |
| `rateLimiting.service.image.tag` | `17b1956c` | Rate limit service image tag aligned with Envoy Gateway v1.9.0 |
| `rateLimiting.externalRedis.host` | `""` | External Redis host |
| `rateLimiting.externalRedis.port` | `6379` | External Redis port |
| `rateLimiting.externalRedis.auth.enabled` | `false` | Enable Redis authentication |
| `rateLimiting.externalRedis.auth.secretName` | `""` | Secret name for Redis password |
| `rateLimiting.externalRedis.auth.secretKey` | `password` | Secret key for Redis password |
| `rateLimiting.presets.api` | `false` | Enable API preset (100 req/min per IP) |
| `rateLimiting.presets.strict` | `false` | Enable strict preset (10 req/min per IP) |
| `redis.enabled` | `false` | Deploy the helmforge/redis subchart for rate limiting |
| `redis.architecture` | `standalone` | Redis topology |
| `redis.auth.enabled` | `true` | Enable Redis password authentication |
| `redis.standalone.persistence.enabled` | `true` | Enable Redis persistent storage |
| `redis.standalone.persistence.size` | `1Gi` | Redis PVC size |

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
| `security.networkPolicies` | `false` | Enable rendering of NetworkPolicy resources |
| `security.networkPolicy.dns.namespace` | `kube-system` | Namespace containing cluster DNS pods allowed by NetworkPolicies |
| `security.networkPolicy.dns.podLabels` | `{"k8s-app":"kube-dns"}` | Labels selecting cluster DNS pods allowed by NetworkPolicies |
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
| `serviceAccount.name` | `""` | ServiceAccount name (generated if empty; must be `envoy-gateway` when rate limiting is enabled) |
| `serviceAccount.annotations` | `{}` | ServiceAccount annotations |
| `rbac.create` | `true` | Create RBAC resources |

### GatewayClass

| Key | Default | Description |
|-----|---------|-------------|
| `gatewayClass.name` | `envoy-gateway` | GatewayClass name |
| `gatewayClass.create` | `true` | Create GatewayClass resource |

### Cleanup

| Key | Default | Description |
|-----|---------|-------------|
| `cleanup.enabled` | `true` | Run a pre-delete cleanup Job for chart-managed Gateways and GatewayClass |
| `cleanup.image.repository` | `docker.io/helmforge/kubectl` | kubectl image used by the cleanup hook |
| `cleanup.image.tag` | `1.35.3` | kubectl image tag |
| `cleanup.image.pullPolicy` | `IfNotPresent` | Cleanup image pull policy |
| `cleanup.timeoutSeconds` | `90` | Timeout in seconds for Gateway and GatewayClass cleanup operations |
| `cleanup.resources.requests.cpu` | `10m` | CPU request for the cleanup hook |
| `cleanup.resources.requests.memory` | `32Mi` | Memory request for the cleanup hook |
| `cleanup.resources.limits.cpu` | `100m` | CPU limit for the cleanup hook |
| `cleanup.resources.limits.memory` | `128Mi` | Memory limit for the cleanup hook |

The cleanup hook runs before uninstall so chart-managed Gateways are deleted
while the controller is still present. It then removes the chart-managed
GatewayClass after verifying that no remaining Gateways reference that class.
If user-managed Gateways still reference the class, the hook exits with a clear
error and Helm leaves the release installed for manual cleanup.

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

### Version 1.3.0 (EG v1.8.0)

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
- Updated to EG v1.8.0 and Redis 8.0.2-alpine

## Upgrade Notes

### Mandatory CRD Migration From 1.10.1 to 2.0.0

Chart 2.0.0 is a major release because it raises the Kubernetes minimum from
1.26 to 1.33 and changes the CRD lifecycle and ownership contract. It is the
required bridge between the application-owned policy and
the standalone `envoy-gateway-crds` release. It also corrects the supported
Kubernetes range from the former `>=1.26` declaration to the upstream v1.9
matrix: Kubernetes 1.33 through 1.36. Upgrade the cluster first if it is outside
that range.

The safe sequence is:

1. Capture all CRD, custom-resource, policy, and binding names, UIDs, and counts.
2. Upgrade this application release with `crds.enabled=true`.
3. Verify `helm.sh/resource-policy=keep` on the safe-upgrade policy and binding.
4. Apply the matching standalone CRD bundle server-side.
5. Install the standalone release with policy management disabled.
6. Upgrade this release with `crds.enabled=false`.
7. Adopt the policy and binding into the standalone release.
8. Verify every captured UID and resource count remains unchanged.

Do not skip step 1: patching only the live object is insufficient because Helm
uses the prior release manifest when deciding what to delete. Exact commands,
Helm 3 fallback, recovery, rollback, and verification are in
[CRD migration from 1.10.1](docs/crd-migration.md).

After ownership transfer, never roll back to an application revision from
before the bridge: it reintroduces the old policy resources. Upgrade a
compatible application version with `crds.enabled=false` instead.

When `crds.enabled=false`, rendering fails early unless all 18 required GVKs
are discoverable. A server-connected install, upgrade, or server-side diff also
checks Gateway API bundle `v1.6.1`/`experimental` and Envoy Gateway bundle
`v1.9.0` annotations.

`docker.io/envoyproxy/gateway:v1.9.0` is the upstream minor update from
`v1.8.3`. The automatically generated issue referenced `1.9.0`, but Docker Hub
publishes the canonical Envoy Gateway image tag with the `v` prefix. This chart
pins the managed Envoy proxy image to
`docker.io/envoyproxy/envoy:distroless-v1.39.0`, aligned with the upstream v1.9
compatibility matrix. The rate limit deployment uses the upstream v1.9.0
default `docker.io/envoyproxy/ratelimit:17b1956c` and honors the
`rateLimiting.service.image` override through the EnvoyGateway configuration.
When rate limiting is enabled, the chart also uses the upstream-required
`envoy-gateway` names for the controller Deployment and ServiceAccount. If the
ServiceAccount is externally managed, set
`serviceAccount.create=false,serviceAccount.name=envoy-gateway`.
The controller Service exposes the rate-limit xDS port `18001`, bundled Redis
uses its `-redis-client` endpoint, and Redis authentication is injected into the
managed rate-limit Deployment through `REDIS_AUTH` from either the bundled or
external Secret.

Envoy Gateway v1.9.0 requires Gateway API v1.6 CRDs and includes stricter CEL
validation for client IP detection, API key extraction, and policy merge
targets. Lua extensions are disabled by default and tracing client sampling now
defaults to zero. EndpointSlice indexing is enabled by default and can increase
controller memory use on large clusters. Review the
[upstream v1.9.0 release notes](https://gateway.envoyproxy.io/news/releases/notes/v1.9.0/)
before upgrading. The supported CRD set is Gateway API v1.6.1 Experimental.
Apply the standalone CRD bundle server-side before the controller upgrade,
correct resources rejected by the new validations, and test existing
Gateway, route, EnvoyProxy, `BackendTrafficPolicy`, `SecurityPolicy`,
EnvoyExtensionPolicy, and EnvoyPatchPolicy resources in staging.

### Version 1.0.0

First stable release with MVP and production features.

## Non-Goals

This chart intentionally does not support:

- **Multiple gateway classes** — Deploy separate releases for multiple GatewayClasses
- **Built-in cert-manager integration** — Manage application TLS externally; chart only runs certgen for controller certs
- **Legacy Ingress API** — Use Gateway API for modern routing capabilities

### Security Scan: `envoy-gateway`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **71.63059%** |

> Security posture acceptable.
