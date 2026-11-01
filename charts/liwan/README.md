<!-- SPDX-License-Identifier: Apache-2.0 -->

# Liwan Helm Chart

Deploy [Liwan](https://liwan.dev) on Kubernetes with the official
`ghcr.io/explodingcamera/liwan:1.8.0` image.

Liwan is a lightweight, privacy-focused web analytics application. It runs as a single Rust service and stores analytics
data in embedded DuckDB under `/data`.

## Features

- Official upstream image pinned by tag
- Single-instance topology aligned with embedded DuckDB
- Persistent `/data` volume for analytics and runtime assets
- `Recreate` rollout strategy to avoid overlapping DuckDB writers
- Public URL wiring through `LIWAN_BASE_URL`
- Ingress and Gateway API exposure options
- Dual-stack Service support
- Opt-in ingress NetworkPolicy with explicit peer support
- Non-root security context with token automount disabled
- Extra manifests, volumes, mounts, labels, and annotations for platform integration

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install liwan helmforge/liwan -f values.yaml
```

OCI registry:

```bash
helm install liwan oci://ghcr.io/helmforgedev/helm/liwan -f values.yaml
```

## Production Example

```yaml
liwan:
  baseUrl: https://analytics.example.com

persistence:
  enabled: true
  size: 5Gi

resources:
  requests:
    cpu: 25m
    memory: 64Mi
  limits:
    cpu: 250m
    memory: 256Mi

ingress:
  enabled: true
  ingressClassName: traefik
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: analytics.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: liwan-tls
      hosts:
        - analytics.example.com
```

## Architecture

The chart renders one Deployment, one Service, and a PVC by default. Liwan listens on container port `9042`; the Service
exposes port `80`.

The Deployment uses `strategy.type: Recreate` because the application stores data in embedded DuckDB. A rolling update
could briefly run two writers against the same data volume, so the chart prefers a short outage during upgrades over a
risky overlapping write window.

Set `liwan.baseUrl` to the public URL used by browsers and tracking scripts:

```yaml
liwan:
  baseUrl: https://analytics.example.com
```

## Tracking Script

After installing Liwan, create a site in the UI and use the generated tracking snippet. A typical snippet looks like:

```html
<script defer src="https://analytics.example.com/script.js" data-site-name="my-site"></script>
```

Keep `liwan.baseUrl`, Ingress hostnames, Gateway API hostnames, and TLS hosts aligned so generated URLs match the public
endpoint.

## Examples

- [Simple internal deployment](examples/simple.yaml)
- [Ingress with TLS](examples/ingress.yaml)
- [Gateway API](examples/gateway-api.yaml)
- [Dual-stack Service](examples/dual-stack.yaml)

## Key Values

| Key | Default | Description |
| --- | --- | --- |
| `image.repository` | `ghcr.io/explodingcamera/liwan` | Liwan image repository. |
| `image.tag` | `"1.8.0"` | Liwan image tag. |
| `liwan.port` | `9042` | Application HTTP port. |
| `liwan.baseUrl` | `""` | Public base URL for UI and tracking scripts. |
| `liwan.extraEnv` | `[]` | Extra environment variables for advanced upstream settings. |
| `persistence.enabled` | `true` | Persist `/data`. |
| `persistence.size` | `2Gi` | PVC size. |
| `service.port` | `80` | Kubernetes Service port. |
| `service.ipFamilyPolicy` | `null` | Optional Service IP family policy. |
| `service.ipFamilies` | `[]` | Optional ordered IP families. |
| `networkPolicy.enabled` | `false` | Enable ingress isolation for the Liwan pod. |
| `networkPolicy.ingressFrom` | `[]` | Allowed peers; empty permits same-namespace pods. |
| `ingress.enabled` | `false` | Render an Ingress. |
| `gatewayAPI.enabled` | `false` | Render a Gateway API HTTPRoute. |
| `serviceAccount.automountServiceAccountToken` | `false` | Mount a Kubernetes API token into the pod. |
| `extraManifests` | `[]` | Additional Kubernetes resources to render with the release. |

## Upgrade to 1.8

Liwan 1.8 retains the secure proxy contract introduced in 1.7: only loopback
proxies and `X-Forwarded-For` are trusted by default.
Behind an Ingress or Gateway, configure the actual proxy IPs or CIDRs through
`liwan.extraEnv`; otherwise analytics records the connecting proxy address.
For example, set `LIWAN_TRUSTED_PROXIES` to `10.42.0.0/16` only when that range
belongs to your trusted ingress proxies. Multiple entries are comma-separated.
Set `LIWAN_TRUSTED_HEADERS` when your proxy uses a different header. Do not
trust arbitrary client-controlled headers or use the unrestricted `*` proxy
setting. The removed `LIWAN_USE_FORWARD_HEADERS` setting now fails chart
validation with a migration message.

Review the [upstream 1.8 release](https://github.com/explodingcamera/liwan/releases/tag/liwan-v1.8.0)
before upgrading. Back up the persistent data directory before the rollout and
keep exactly one writer during recovery.

## Network isolation

NetworkPolicy is disabled by default so upgrades preserve established ingress
paths. Enable it only after identifying the namespace and Pod selectors used by
your Ingress or Gateway controller:

```yaml
networkPolicy:
  enabled: true
  ingressFrom:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-system
      podSelector:
        matchLabels:
          app.kubernetes.io/name: ingress-controller
```

An empty `ingressFrom` permits same-namespace pods. Enforcement requires a CNI
that implements Kubernetes NetworkPolicy. Set `podSelector` labels to match the
actual edge controller. NetworkPolicies are additive, so inspect every policy
selecting the Liwan Pod before relying on this policy for isolation.

## Operations

Check rollout:

```bash
kubectl rollout status deployment/liwan-liwan
kubectl get deployment,svc,pvc -l app.kubernetes.io/name=liwan,app.kubernetes.io/instance=liwan
```

Port-forward for local access:

```bash
kubectl port-forward svc/liwan-liwan 9042:80
```

Back up the PVC mounted at `/data`. For consistent snapshots, pause writes or scale the Deployment to zero before taking
a storage-level snapshot.

## Security

Default security posture:

- ServiceAccount token automount disabled
- non-root UID/GID `1000`
- `fsGroup: 1000`
- `fsGroupChangePolicy: OnRootMismatch`
- `seccompProfile.type: RuntimeDefault`
- `allowPrivilegeEscalation: false`
- `capabilities.drop: [ALL]`

Resource requests and limits are intentionally user-defined because Liwan traffic profiles vary by site. Set them for
production to satisfy cluster policy and capacity planning.

## Troubleshooting

- If the Pod is pending, confirm the PVC is bound and the requested StorageClass
  exists.
- If tracking records the proxy address, configure only the actual proxy CIDRs in
  `LIWAN_TRUSTED_PROXIES` and verify the forwarded header name.
- If NetworkPolicy blocks traffic, compare the edge Pod and namespace labels with
  `networkPolicy.ingressFrom` before widening access.
- If data appears missing, verify the mounted claim and never start a second
  writer against the previous DuckDB directory.

## Security Scan: `liwan`

| Framework | Score |
| --- | --- |
| Overall | **84.85%** |
| MITRE | **100.00%** |
| NSA | **80.00%** |
| SOC2 | **80.00%** |

Security posture acceptable. Remaining findings are resource limits, network policy, and immutable root filesystem,
which are environment-specific choices for this chart.

## Documentation

- [Architecture](docs/architecture.md)
- [Operations](docs/operations.md)
- [Liwan official documentation](https://liwan.dev)
- [Upstream source](https://github.com/explodingcamera/liwan)
