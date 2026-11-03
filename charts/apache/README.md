# Apache

Apache HTTP Server is a widely used open source web server for static content,
reverse proxy entrypoints, and internal HTTP endpoints.

This HelmForge chart deploys the official `docker.io/library/httpd` image with
secure non-root defaults, a read-only root filesystem, generated Apache
configuration, optional Basic Auth, Gateway API, Ingress, NetworkPolicy,
dual-stack Service fields, Apache exporter metrics, ServiceMonitor, PDB, HPA,
ExternalSecret support, and Helm tests.

## Installation

Install from the HelmForge HTTPS repository:

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install apache helmforge/apache --namespace apache --create-namespace
```

Install from OCI:

```bash
helm install apache oci://ghcr.io/helmforgedev/helm/apache \
  --namespace apache \
  --create-namespace
```

## Features

- Official Apache HTTP Server image only, pinned to `2.4.69`.
- Non-root runtime on port `8080` with `RuntimeDefault` seccomp and dropped
  Linux capabilities.
- Read-only root filesystem with explicit writable `emptyDir` volumes for logs
  and temporary files.
- Generated hardened `httpd.conf` with configurable `ServerTokens`,
  `ServerSignature`, `TraceEnable`, directory options, and extra vhost snippets.
- Static content from inline values or an operator-managed ConfigMap.
- Ingress and Gateway API support without mixing their value contracts.
- Optional Basic Auth through an existing Secret or ExternalSecret-managed
  Secret.
- Metrics sidecar and ServiceMonitor for Prometheus Operator environments.
- NetworkPolicy, dual-stack Service fields, PDB, HPA, and Helm test coverage.

## Examples

Inline content is useful for smoke tests and small internal landing pages:

```yaml
content:
  files:
    index.html: |
      <!doctype html>
      <html lang="en">
      <body>
        <h1>Hello from Apache</h1>
      </body>
      </html>
```

For production, keep content ownership outside the Helm release and point the
chart to an immutable ConfigMap:

```yaml
replicaCount: 3

content:
  existingConfigMap: apache-site-content-20260613

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 1
    memory: 512Mi

pdb:
  enabled: true
  minAvailable: 1
```

## Configuration

The complete contract and defaults are defined in [`values.yaml`](./values.yaml)
and validated by [`values.schema.json`](./values.schema.json). The most common
settings are:

| Value | Default | Purpose |
|---|---|---|
| `replicaCount` | `2` | Apache replicas when autoscaling is disabled. |
| `image.repository` | `docker.io/library/httpd` | Official Apache image repository. |
| `image.tag` | `2.4.69` | Pinned Apache image tag. |
| `containerPorts.http` | `8080` | Non-root listener used by Apache and probes. |
| `service.port` | `80` | Client-facing Service port. |
| `content.existingConfigMap` | `""` | Existing immutable content ConfigMap; inline content is used when empty. |
| `basicAuth.enabled` | `false` | Mount an htpasswd file from the configured Secret. |
| `serverStatus.enabled` | `false` | Enable the local `mod_status` endpoint. |
| `ingress.enabled` | `false` | Render an Ingress. |
| `gateway.enabled` | `false` | Render a Gateway API HTTPRoute. |
| `networkPolicy.enabled` | `false` | Render ingress and egress NetworkPolicies. |
| `metrics.enabled` | `false` | Run the Apache exporter sidecar. |
| `metrics.serviceMonitor.enabled` | `false` | Render a Prometheus Operator ServiceMonitor. |
| `autoscaling.enabled` | `false` | Use an HPA instead of the fixed replica count. |
| `pdb.enabled` | `false` | Render a PodDisruptionBudget. |
| `externalSecrets.enabled` | `false` | Materialize the Basic Auth Secret with ESO. |

`containerPorts.http` controls the actual Apache `Listen` directive. It is
independent from `service.port`, which controls only the Kubernetes Service.
Arbitrary Kubernetes scheduling, resource, environment, volume, and manifest
objects remain pass-through values so existing platform-specific overrides are
preserved during upgrades.

## Routing

Use `ingress.ingressClassName` for classic Kubernetes Ingress:

```yaml
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: apache.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: apache-tls
      hosts:
        - apache.example.com
```

Gateway API uses the `gateway` block and renders an HTTPRoute:

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: public-gateway
      namespace: gateway-system
  hostnames:
    - apache.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
```

Dual-stack Service settings are exposed directly:

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

## Authentication And Secrets

Basic Auth expects an htpasswd file from a Kubernetes Secret:

```yaml
basicAuth:
  enabled: true
  existingSecret: apache-basicauth
  htpasswdKey: htpasswd
```

GitOps installations can let External Secrets Operator materialize that Secret:

```yaml
basicAuth:
  enabled: true
  existingSecret: apache-basicauth

externalSecrets:
  enabled: true
  secretStoreRef:
    name: cluster-secrets
    kind: ClusterSecretStore
  data:
    - secretKey: htpasswd
      remoteRef:
        key: apache/basicauth
        property: htpasswd
```

## Metrics

Metrics use the Apache exporter sidecar and the `mod_status` endpoint:

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    labels:
      release: prometheus
```

`metrics.enabled` also renders the local `mod_status` endpoint required by the
sidecar. Use `serverStatus.enabled` only when status is needed without the
exporter; keep its `Require` expression restricted. In production, combine
metrics with NetworkPolicy and ServiceMonitor selectors so only trusted scrape
paths can reach the exporter port.

## Network Policy

The chart can render explicit ingress and egress boundaries:

```yaml
networkPolicy:
  enabled: true
  ingress:
    enabled: true
    namespaceSelector:
      kubernetes.io/metadata.name: ingress-nginx
  egress:
    enabled: true
    allowDns: true
    allowInternet: false
```

Set `allowInternet=true` only when Apache needs outbound access for proxying or
remote content retrieval through extra configuration.

## Upgrade Notes

Apache HTTP Server 2.4.69 removes legacy RFC 2069 compatibility from
`mod_auth_digest`. Deployments that inject custom Digest-auth configuration
must ensure every client supports the RFC 2617 or later challenge format before
upgrading. The chart does not enable `mod_auth_digest` by default.

## Validation

After installing the chart:

```bash
helm test apache -n apache
kubectl get pods -n apache -l app.kubernetes.io/name=apache
kubectl logs -n apache deploy/apache --all-containers --since=10m
kubectl get events -n apache --sort-by=.lastTimestamp
```

The chart exposes `/healthz` for probes and Helm tests. If you replace the
generated Apache configuration, keep `/healthz` available or update the probe
paths to match your served content.

## Troubleshooting

- If pods fail readiness, inspect the rendered `httpd.conf` and confirm that
  `/healthz` remains served on `containerPorts.http`.
- If Basic Auth prevents startup, verify that `basicAuth.existingSecret`
  exists and contains `basicAuth.htpasswdKey` in the release namespace.
- If metrics are unavailable, enable `metrics.enabled`, verify the exporter can
  reach local `mod_status`, and allow the metrics port through NetworkPolicy.
- If an HTTPRoute is not accepted, inspect its parent status and confirm that
  the referenced Gateway permits routes from the release namespace.

## Security Scan

🟢 Security Scan: `apache`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **93.43435%** |

> ✅ Security posture acceptable.

Local details:

| Framework | Score |
|---|---|
| MITRE | 100.00% |
| NSA | 91.67% |
| SOC2 | 90.00% |

## Documentation

- [Design](./DESIGN.md)
- [Production guide](./docs/production.md)
- [Networking](./docs/networking.md)
- [External Secrets](./docs/external-secrets.md)
- [Apache HTTP Server](https://httpd.apache.org)
- [Official Apache image](https://hub.docker.com/_/httpd)
