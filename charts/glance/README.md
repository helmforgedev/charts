# Glance

Glance puts feeds, bookmarks and operational widgets into a configurable dashboard.
This chart deploys the [official Glance application](https://github.com/glanceapp/glance)
with native login enabled, retained credentials and a restricted Kubernetes runtime.

## Why this chart

- Private bootstrap with a generated password and the correct 64-byte signing key.
- Existing Secret and External Secrets support for login and widget credentials.
- Literal native widget configuration, including custom-api Go templates.
- Non-root, read-only execution without a Docker socket or Kubernetes API token.
- Explicit network boundaries, TLS routing integrations and dual-stack Services.
- Tested session continuity through Helm upgrade and pod replacement.

## Architecture

A Deployment runs the official docker.io/glanceapp/glance:v0.8.6 image on port 8080.
The application needs no database, cache service or persistent data volume.
Configuration lives in a ConfigMap; authentication and widget tokens live in Secrets.
The chart configures one native dashboard account. It is not a multi-tenant portal.
Multiple replicas share session-signing material but maintain independent caches
and authentication rate limits. See [DESIGN.md](DESIGN.md) for these boundaries.

## Install

~~~sh
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm upgrade --install glance helmforge/glance --namespace glance --create-namespace
~~~

OCI is also supported:

~~~sh
helm upgrade --install glance oci://ghcr.io/helmforgedev/helm/glance --namespace glance --create-namespace
~~~

Use helm get notes glance -n glance to locate the generated Secret and credentials.
Do not expose the Service publicly before configuring TLS and trusted ingress peers.

## Quick start

~~~sh
kubectl -n glance rollout status deployment/glance-glance --timeout=120s
kubectl -n glance port-forward svc/glance-glance 8080:8080
~~~

Open <http://localhost:8080> and sign in as admin using the password from the Secret
shown in the notes. The default dashboard contains a HelmForge bookmark and calendar;
it does not send tokens to third-party feeds. The localhost tunnel is a lab access
path, not a replacement for TLS termination in production.

## Production deployment

Start from [examples/production.yaml](examples/production.yaml). Create glance-auth
and the TLS Secret in the release namespace first. The auth Secret must contain
password and secret-key. The signing value is base64 encoding of 64 random bytes.
The example uses two replicas, an optional PDB and a restricted ingress controller
peer. Adapt hostnames, Secret names and scheduling to the actual cluster.

For an existing Gateway, use [examples/gateway.yaml](examples/gateway.yaml).
The Gateway listener owns TLS. A route path match does not strip a URL prefix:
subpath users must configure rewriting at the proxy and set server.baseUrl.
Keep server.proxied false unless only trusted proxy peers can reach the Service.

## Authentication and widgets

See [authentication](docs/authentication.md) for generated credential retention,
External Secrets and rotation. Use an externally owned Secret with offline GitOps
renderers; helm template cannot perform cluster lookup. Changing the signing key
invalidates existing sessions. Changing an external Secret requires a rollout.

See [widget configuration](docs/widgets-and-network.md) for file interpolation,
custom-api templates and scoped egress. config.data uses native Glance syntax and
does not evaluate Helm tpl. auth and server are reserved chart-managed sections.
Static assets are public; never put credentials into an assets ConfigMap.

## Persistence and backup

There is no server-side application database or content PVC. Preserve the complete
configuration, credential source and assets. Browser-local Todo data is not part
of a Kubernetes backup. [Operations](docs/operations.md) explains recovery and
the distinction between process availability and third-party feed health.

## Monitoring and availability

Native /api/healthz supports startup, readiness and liveness probes. No native
Prometheus endpoint was found in this release; use an existing blackbox exporter
for HTTP/TLS availability. A ServiceMonitor pointing at ordinary HTML would not
provide application metrics. Multiple replicas do not share login rate counters;
enforce suitable edge limits for sensitive public dashboards.

## Configuration reference

| Value | Default | Purpose |
|---|---|---|
| `nameOverride` | `""` | Override the chart name used in resource names. |
| `fullnameOverride` | `""` | Override the complete resource name. |
| `commonLabels` | `{}` | Extra resource labels; selector labels are reserved. |
| `replicaCount` | `1` | Glance replicas. Authentication rate limiting and widget caches are per pod. |
| `image.repository` | `docker.io/glanceapp/glance` | Official upstream Glance image. |
| `image.tag` | `v0.8.6` | Verified stable image tag. |
| `image.pullPolicy` | `IfNotPresent` | Kubernetes pull policy. |
| `imagePullSecrets` | `[]` | Registry credentials for a private mirror. |
| `auth.enabled` | `true` | Require native Glance login. Disable only behind a separately authenticated edge or for public dashboards. |
| `auth.username` | `admin` | Initial dashboard username; all authenticated users see the same dashboard. |
| `auth.password` | `""` | Password stored only in a Secret. Empty generates and retains a random password. |
| `auth.secretKey` | `""` | Base64 encoding of exactly 64 random bytes for session signing. Empty generates and retains it. |
| `auth.existingSecret` | `""` | Existing Secret containing password and secret-key; bypasses generated credentials. |
| `auth.passwordKey` | `password` | Password key in the existing Secret. |
| `auth.secretKeyKey` | `secret-key` | Signing key in the existing Secret. |
| `server.port` | `8080` | Container listen port; Service and probes follow this value. |
| `server.proxied` | `false` | Trust proxy headers. Enable only when network ingress is restricted to trusted proxies. |
| `server.baseUrl` | `""` | External subpath, such as /glance. The reverse proxy must strip this prefix before forwarding. |
| `config.data` | `object` | Upstream Glance configuration. auth and server are chart-managed and forbidden here. Go widget templates remain literal; Helm tpl is not applied. |
| `assets.existingConfigMap` | `""` | Existing ConfigMap containing public static assets mounted at /app/assets. Never put credentials here. |
| `widgetSecrets.sources` | `[]` | Additional Secret files mounted under /run/secrets; reference with ${secret:filename} in config.data. |
| `extraEnv` | `[]` | Extra environment variables for Glance configuration substitutions. |
| `envFrom` | `[]` | Additional envFrom Secret/ConfigMap references. |
| `serviceAccount.create` | `true` | Create a dedicated ServiceAccount with no API permissions. |
| `serviceAccount.name` | `""` | Existing or overridden ServiceAccount name. |
| `serviceAccount.annotations` | `{}` | ServiceAccount annotations. |
| `serviceAccount.automountServiceAccountToken` | `false` | Mount a Kubernetes API token. Glance does not need one. |
| `service.type` | `ClusterIP` | Kubernetes Service type. |
| `service.port` | `8080` | Service HTTP port. |
| `service.annotations` | `{}` | Service annotations. |
| `service.ipFamilyPolicy` | `""` | Service IP family policy; empty uses cluster default. |
| `service.ipFamilies` | `[]` | Requested address families; RequireDualStack needs a dual-stack cluster. |
| `ingress.enabled` | `false` | Enable Ingress. TLS is configured through ingress.tls. |
| `ingress.ingressClassName` | `""` | Ingress controller class; empty omits the field. |
| `ingress.annotations` | `{}` | Controller-specific annotations, including any required prefix stripping. |
| `ingress.hosts` | `[]` | Host/path rules; at least one explicit host is required when enabled. |
| `ingress.tls` | `[]` | TLS host/Secret entries. |
| `gatewayAPI.enabled` | `false` | Enable a Gateway API v1 HTTPRoute. Install Gateway API CRDs and a controller first. |
| `gatewayAPI.httpRoutes[].annotations` | `{}` | HTTPRoute annotations. |
| `gatewayAPI.httpRoutes[].parentRefs` | `[]` | Existing Gateway parent references, including namespace when appropriate. |
| `gatewayAPI.httpRoutes[].hostnames` | `[]` | Public DNS hostnames. |
| `gatewayAPI.httpRoutes[].rules[].matches[].path.value` | `/` | Matched HTTP path. Subpaths require an external prefix-stripping rule. |
| `gatewayAPI.httpRoutes[].rules[].matches[].path.type` | `PathPrefix` | Gateway path match type. |
| `externalSecrets.enabled` | `false` | Render ExternalSecret objects for auth or widget credentials. |
| `externalSecrets.refreshInterval` | `1h` | Default operator refresh interval. |
| `externalSecrets.items` | `[]` | Full ExternalSecret specifications. auth.existingSecret must match the target Secret name. |
| `networkPolicy.enabled` | `true` | Isolate ingress and allow declared outgoing feeds. Requires a NetworkPolicy-capable CNI. |
| `networkPolicy.ingressFrom` | `[]` | Allowed ingress peers. Empty permits pods in the same namespace only. |
| `networkPolicy.egressIsolation` | `true` | Enable outbound isolation, allowing DNS and configured web ports. |
| `networkPolicy.dnsEgress` | `object` | DNS peers; defaults to cluster pods in any namespace, restricted to DNS ports. |
| `networkPolicy.webEgress` | `object` | Destinations for HTTP/HTTPS feeds. Replace broad CIDRs for a restricted intranet dashboard. |
| `networkPolicy.webPorts` | `[80, 443]` | Allowed feed ports; TCP only. Internal non-HTTP widgets need extraEgress. |
| `networkPolicy.extraEgress` | `[]` | Additional egress rules, for example internal APIs on alternate ports. |
| `probes.startup` | `{enabled: true, path: /api/healthz, periodSeconds: 5, timeoutSeconds: 2, failureThreshold: 30}` | Startup health endpoint; native /api/healthz remains unauthenticated. |
| `probes.liveness` | `{enabled: true, path: /api/healthz, periodSeconds: 20, timeoutSeconds: 3, failureThreshold: 3}` | Liveness checks process health without depending on external feeds. |
| `probes.readiness` | `{enabled: true, path: /api/healthz, periodSeconds: 10, timeoutSeconds: 3, failureThreshold: 3}` | Readiness checks the initialized HTTP server. |
| `resources` | `object` | Resource requests and limits for the Go dashboard; size for widget count and feed payloads. |
| `podSecurityContext` | `object` | Non-root pod identity with RuntimeDefault seccomp. |
| `securityContext` | `object` | Restricted container privileges; all configuration and assets are read-only. |
| `podDisruptionBudget.enabled` | `false` | Protect voluntary disruptions. Requires at least two replicas; no singleton eviction deadlock. |
| `podDisruptionBudget.maxUnavailable` | `1` | Maximum unavailable pods during voluntary disruption. |
| `podLabels` | `{}` | Pod labels; immutable selector labels cannot be overridden. |
| `podAnnotations` | `{}` | Pod annotations, e.g. for an external Secret reloader. |
| `nodeSelector` | `{}` | Node selection constraints. |
| `tolerations` | `[]` | Scheduling tolerations. |
| `affinity` | `{}` | Pod affinity or anti-affinity. |
| `topologySpreadConstraints` | `[]` | Topology spreading across nodes or zones. |
| `priorityClassName` | `""` | Scheduling priority class. |
| `terminationGracePeriodSeconds` | `30` | Grace period for HTTP shutdown. |

## Examples and prerequisites

| Example | Intended use | Required existing resources |
|---|---|---|
| [minimal](examples/minimal.yaml) | Private local dashboard | None |
| [production](examples/production.yaml) | Two replicas behind TLS Ingress | Auth Secret, TLS Secret and ingress controller |
| [gateway](examples/gateway.yaml) | Shared Gateway listener | Gateway API CRDs and configured HTTPS listener |
| [secret widgets](examples/secret-widgets.yaml) | Authenticated release feeds | Widget token Secret |
| [external secrets](examples/external-secrets.yaml) | Provider-managed login | ESO and configured ClusterSecretStore |
| [public dashboard](examples/public-dashboard.yaml) | Deliberately public links | Explicit operator acceptance of anonymous access |

CI fixtures are disposable test data, not production credentials.
All native configuration examples should be checked against the pinned upstream
configuration reference before adding widget-specific options.

## Upgrades and recovery

Review [upstream releases](https://github.com/glanceapp/glance/releases) before
upgrading. Confirm the effective image after rollout. Preserve the signing key,
username and credential source to retain sessions. With image bumps, blindly
using --reuse-values can keep the previous image tag; prefer deliberate values
or --reset-then-reuse-values. Test important third-party widgets after upgrading.

To recover onto a new cluster, restore configuration, assets and the Secret source
first, then install the chart with the same references. No schema migration or
database restore is required for this stateless application. Recover browser data
through the browser's own profile backups where appropriate.

## Troubleshooting

The [operations guide](docs/operations.md) provides symptom-driven checks for login,
Secret synchronization, ports, subpath assets, network policy, widgets and scheduling.
Start with helm status, Deployment rollout status, pod events and current logs.
Do not disable authentication or network isolation merely to hide a failing test.

## Validation

Helm tests cover the configuration, credentials, network, routing and scheduling
contracts. The chart-owned runtime smoke exercises real login, rejection of empty
credentials, rendered widgets, Helm upgrade and pod replacement. A dedicated
widget fixture checks Secret interpolation and literal Glance Go templates.
The complete HelmForge gate includes CRD schemas and actual k3d deployments.

## Security Scan

### Security Scan: `glance`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **100%** |

> Security posture acceptable.

Measured with Kubescape 4.0.13 against the default rendered manifests. This is
a configuration assessment, not a guarantee of application security.

## Support

- [HelmForge documentation](https://helmforge.dev/docs/charts/glance)
- [Report chart issues](https://github.com/helmforgedev/charts/issues)
- [Official Glance configuration](https://github.com/glanceapp/glance/blob/v0.8.6/docs/configuration.md)
- [Official Glance releases](https://github.com/glanceapp/glance/releases)

HelmForge charts are licensed under Apache-2.0. The deployed upstream application
retains its own license. Contributions should include a reproducible configuration
with secrets removed and evidence of the failing behavior.

<!-- @AI-METADATA
type: guide
title: Glance README
description: Product-specific Glance deployment and operation contract
keywords: glance, helm, authentication, widgets, kubernetes
purpose: Operate the Glance chart safely
scope: charts/glance
-->

## Gateway API contract

Use `gatewayAPI.enabled` and `gatewayAPI.httpRoutes[]`. Set each route's `parentRefs` to a shared Gateway that allows
this namespace, and configure its HTTPS listener and public hostname. Routes accept labels, annotations and rules
with matches, filters and optional backend references; omitted backends target this chart's application Service.
Ingress and HTTPRoute resources can coexist. Verify controller conditions and public traffic before production use.
See the [Gateway API documentation](https://gateway-api.sigs.k8s.io/).
